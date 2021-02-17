const print = @import("std").debug.print;

const attack = @import("attack.zig");
const bitboard = @import("bitboard.zig");
const color = @import("color.zig");
const move = @import("move.zig");
const piece = @import("piece.zig");
const position = @import("position.zig");
const square = @import("square.zig");
const Bitboard = bitboard.Bitboard;
const Color = color.Color;
const Move = move.Move;
const MoveList = move.MoveList;
const Square = square.Square;
const PieceType = piece.PieceType;
const Piece = piece.Piece;
const Position = position.Position;
const pawn = PieceType.pawn;

pub fn legalMoves(pos: Position) callconv(.Inline) !MoveList {
    var moves = MoveList.new();
    const king: Square = pos.our(PieceType.king).toSquare().?;
    if (!pos.isCheck()) {
        const not_us = pos.us().invert();
        // generate normal moves for all the pieces, could be illegal due to induced check
        try pieceMoves(&moves, pos, PieceType.knight, not_us);
        try pieceMoves(&moves, pos, PieceType.bishop, not_us);
        try pieceMoves(&moves, pos, PieceType.rook, not_us);
        try pieceMoves(&moves, pos, PieceType.queen, not_us);
        try pawnMoves(&moves, pos, not_us);
        try kingMoves(&moves, pos, not_us); // normal king moves
        try castlingMoves(&moves, pos, king); // only not in check
    } else {
        try evasions(&moves, pos);
    }
    const blockers = pos.board.sliderBlockers(pos.them(), king);
    if (blockers.isNotEmpty() or pos.en_passant != null) {
        var i: usize = 0;
        while (i < moves.len) {
            if (isSafe(&moves.items[i], pos, king, blockers)) {
                i += 1;
            } else {
                _ = moves.swapRemove(i);
            }
        }
    }
    return moves;
}

fn isSafe(m: *Move, pos: Position, king: Square, blockers: Bitboard) callconv(.Inline) bool {
    if (m.mover == PieceType.king) return true;
    if ((m.mover == PieceType.pawn) and (m.result == PieceType.pawn) and m.special) {
        var occupied = pos.board.occupied();
        occupied.toggle(m.from);
        occupied.toggle(Square{ .file = m.to.file, .rank = m.from.rank });
        occupied = occupied.addSquare(m.to);
        const rooks_and_queens = pos.board.rooks.bitxor(pos.board.queens);
        const bishops_and_queens = pos.board.bishops.bitxor(pos.board.queens);
        const r_ray = attack.rookFrom(king, occupied).bitand(pos.them());
        const b_ray = attack.bishopFrom(king, occupied).bitand(pos.them());
        return (r_ray.bitand(rooks_and_queens)).isEmpty() and b_ray.bitand(bishops_and_queens).isEmpty();
    } else {
        return !blockers.contains(m.from) or attack.aligned(m.from, m.to, king);
    }
}

fn pieceMoves(moves: *MoveList, pos: Position, mover_type: PieceType, target: Bitboard) callconv(.Inline) !void {
    const pce = Piece{ .piece_type = mover_type, .color = pos.color };
    var from_iter = pos.our(mover_type);
    while (from_iter.next()) |from| {
        var to_iter = attack.pieceFrom(from, pce, pos.board.occupied()).bitand(target);
        while (to_iter.next()) |to| {
            const captured_type = try pos.board.pieceTypeOn(to);
            try moves.push(Move.new(from, to, false, mover_type, captured_type));
        }
    }
}

fn pawnMoves(moves: *MoveList, pos: Position, target: Bitboard) callconv(.Inline) !void {
    const not_eighth_rank = bitboard.relativeRank(pos.color, 7).invert(); // 7 is 8th rank
    const pawntarget = target.bitand(not_eighth_rank).bitand(pos.them()); // them not on 8th
    // non-seventh rank pawn captures
    try pieceMoves(moves, pos, pawn, pawntarget);
    { // 7th rank pawn captures and promotions
        var from_iter = pos.our(pawn).bitand(bitboard.relativeRank(pos.color, 6)); // 7th rank
        while (from_iter.next()) |from| {
            var to_iter = attack.pawnFrom(pos.color, from).bitand(pos.them()).bitand(target);
            while (to_iter.next()) |to| {
                const captured_type = try pos.board.pieceTypeOn(to);
                try pushPawnPromotions(moves, from, to, captured_type);
            }
        }
    }
    // advance all our pawns one step forward to any empty squares
    const single_moves = pos.our(pawn).relativeShift(pos.color, 8).bitand(pos.board.empty);
    {
        var to_iter = single_moves.bitand(target);
        while (to_iter.next()) |to| {
            if (to.offset(pos.color.wlbr(i32, -8, 8))) |from| {
                // "mover" type becomes the "promoted to" type
                if ((to.rank == 7) or (to.rank == 0)) { // back ranks
                    try pushPawnPromotions(moves, from, to, PieceType.empty);
                } else {
                    try moves.push(Move.new(from, to, false, pawn, PieceType.empty));
                }
            }
        }
    }
    // advance our pawns that moved a single square, a second step forward to any empty squares
    const double_moves = single_moves.relativeShift(pos.color, 8).bitand(pos.board.empty);
    {
        var to_iter = double_moves.bitand(bitboard.relativeRank(pos.color, 3)).bitand(target);
        while (to_iter.next()) |to| {
            if (to.offset(pos.color.wlbr(i32, -16, 16))) |from| {
                try moves.push(Move.new(from, to, true, pawn, PieceType.empty));
            }
        }
    }
    // en passant ... I should be able to optimize this...
    if (pos.en_passant) |ep_square| {
        const ep_file: i8 = @as(i8, ep_square.file);
        var fifth_rank = pos.our(pawn).bitand(bitboard.relativeRank(pos.color, 4));
        while (fifth_rank.next()) |from| {
            const pawn_file: i8 = @as(i8, from.file);
            if (((ep_file + 1) == pawn_file) or ((ep_file - 1) == pawn_file)) {
                try moves.push(Move.new(from, ep_square, true, pawn, PieceType.pawn));
            }
        }
    }
}

fn kingMoves(moves: *MoveList, pos: Position, target: Bitboard) callconv(.Inline) !void {
    // try move_list.append((try pos.pieceMoves(PieceType.king, target)).constSlice());
    const king: Square = pos.our(PieceType.king).toSquare().?;
    var king_moves = attack.kingFrom(king).bitand(target);
    while (king_moves.next()) |to| {
        if (pos.board.attackersOf(to, pos.theirColor()).isEmpty()) {
            const captured_piece = try pos.board.pieceTypeOn(to);
            try moves.push(Move.new(king, to, false, PieceType.king, captured_piece));
        }
    }
}

fn castlingMoves(moves: *MoveList, pos: Position, king: Square) callconv(.Inline) !void {
    // expects that the checkers to the king are 0
    const back_rank: Bitboard = bitboard.relativeRank(pos.color, 0);
    var rook_squares: Bitboard = pos.castles.bitand(back_rank); // the corner squares
    while (rook_squares.next()) |rook| { // rook corner squares
        const side = if (king.distance(rook) == 3) bitboard.kingside else bitboard.queenside;
        const back_side = side.bitand(back_rank); // the four corner squares
        const collision_path = bitboard.rook_path.bitand(back_side); // squares the rook goes through
        if (collision_path.bitand(pos.board.occupied()).isNotEmpty()) continue; // in the way!
        var king_walk = back_side.bitand(bitboard.king_path); // squares the king goes through
        var found_attacker = false;
        while (king_walk.next()) |kwalk_square| { // check for attackers and abort if any!
            if (pos.board.attackersOf(kwalk_square, pos.theirColor()).isNotEmpty()) {
                found_attacker = true;
            }
        }
        if (!found_attacker) {
            const castle = bitboard.king_castle.bitand(back_side).toSquare().?;
            const mover = if (king.distance(rook) == 3) PieceType.king else PieceType.queen;
            try moves.push(Move.new(king, castle, true, PieceType.king, mover));
        }
    }
}

fn evasions(moves: *MoveList, pos: Position) callconv(.Inline) !void {
    const king: Square = pos.our(PieceType.king).toSquare().?;
    var attacked = bitboard.empty;
    var sliders = pos.checkers.bitand(pos.board.sliders());
    while (sliders.next()) |checker| {
        attacked.bits |= (attack.ray(checker, king).bits ^ checker.toBitboard().bits);
    }
    try kingMoves(moves, pos, (pos.us().bitor(attacked)).invert());
    // if single checker then we can capture the checker or block any of the squares between
    if (pos.checkers.isOneSquare()) {
        const target = attack.between(king, pos.checkers.toSquare().?).bitor(pos.checkers);
        try pieceMoves(moves, pos, PieceType.knight, target);
        try pieceMoves(moves, pos, PieceType.bishop, target);
        try pieceMoves(moves, pos, PieceType.rook, target);
        try pieceMoves(moves, pos, PieceType.queen, target);
        try pawnMoves(moves, pos, target);
    }
}

/// Convienience function the code a bit cleaner for move pushing
pub fn pushPawnPromotions(moves: *MoveList, from: Square, to: Square, result: PieceType) callconv(.Inline) !void {
    try moves.push(Move.new(from, to, true, PieceType.knight, result));
    try moves.push(Move.new(from, to, true, PieceType.bishop, result));
    try moves.push(Move.new(from, to, true, PieceType.rook, result));
    try moves.push(Move.new(from, to, true, PieceType.queen, result));
}
