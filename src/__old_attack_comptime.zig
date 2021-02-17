const square = @import("square.zig");
const bitboard = @import("bitboard.zig");
const color = @import("color.zig");
const piece = @import("piece.zig");
const magic = @import("magic.zig");
const Piece = piece.Piece;
const PieceType = piece.PieceType;
const Bitboard = bitboard.Bitboard;
const Square = square.Square;
const Color = color.Color;

pub const rook_shift: usize = 12;
pub const bishop_shift: usize = 9;

pub const white_pawn_offsets = [2]i32{ 7, 9 };
pub const black_pawn_offsets = [2]i32{ -7, -9 };
pub const knight_offsets = [8]i32{ 17, 15, 10, 6, -17, -15, -10, -6 };
pub const bishop_offsets = [4]i32{ 9, 7, -9, -7 };
pub const rook_offsets = [4]i32{ 8, 1, -8, -1 };
pub const king_offsets = [8]i32{ 9, 8, 7, 1, -9, -8, -7, -1 };

pub const white_pawn_attacks: comptime [64]Bitboard = basic_attacks(&white_pawn_offsets);
pub const black_pawn_attacks: comptime [64]Bitboard = basic_attacks(&black_pawn_offsets);
pub const knight_attacks: comptime [64]Bitboard = basic_attacks(&knight_offsets);
pub const king_attacks: comptime [64]Bitboard = basic_attacks(&king_offsets);
pub const rook_bishop_attacks: comptime [88772]Bitboard = sliding_attacks();
// pub const rook_bishop_rays: [64][64]Bitboard = rays(&bishop_offsets, &rook_offsets);

pub fn pawnAttacksFrom(clr: Color, sq: Square) Bitboard {
    return switch (clr) {
        .white => white_pawn_attacks[square.index()],
        .black => black_pawn_attacks[square.index()],
    };
}

// pub fn knightAttacksFrom(sq: Square) Bitboard {
//     return knight[square.index()];
// }

// pub fn bishopAttacksFrom(sq: Square, occupied: Bitboard) Bitboard {
//     return
// }

pub fn rookAttacksFrom(sq: Square, occupied: Bitboard) Bitboard {
    const m = magic.rook[sq.index()];
    const i = (m.factor *% (occupied.bits & m.mask)) >> (64 - bishop_shift) + m.offset;
    return rook_bishop_attacks[i];
}

/// why is this exclusive or?
pub fn queenAttacksFrom(sq: Square, occupied: Bitboard) Bitboard {
    return rookAttacksFrom(sq, occupied).bitxor(bishopAttacksFrom(sq, occupied));
}

pub fn fromPieceAt(sq: Square, pce: Piece, occupied: Bitboard) Bitboard {
    return switch (pce.piece_type) {
        .pawn => pawnAttacksFrom(pce.color, sq),
        .knight => knightAttacksFrom(sq),
        .bishop => bishopAttacksFrom(sq, occupied),
        .rook => rookAttacksFrom(sq, occupied),
        .queen => queen_attacks(sq, occupied),
        .king => king_attacks(sq),
        .empty => bitboard.empty,
    };
}

const CarryRippler = struct {
    full: Bitboard,
    subset: Bitboard,
    initial: bool,

    fn next(self: CarryRippler) ?Bitboard {
        return null;
    }
};

fn attack(comptime sq: Square, occupied: Bitboard, offsets: []const i32) Bitboard {
    @setEvalBranchQuota(1_000_000); // default of 1_000 is not enough for this function;
    comptime var atk = bitboard.empty;
    comptime var i = 0;
    while (i < offsets.len) : (i += 1) {
        comptime var previous = sq;
        while (previous.offset(offsets[i])) |s| {
            if (s.distance(previous) > 2) {
                break;
            }
            atk = atk.addSquare(s);
            if (occupied.contains(s)) {
                break;
            }
            previous = s;
        }
    }
    return atk;
}

fn basic_attacks(comptime offsets: []const i32) [64]Bitboard {
    comptime var attacks: [64]Bitboard = undefined;
    for (attacks) |*atk, i| {
        atk.* = attack(square.fromInt(usize, i), bitboard.all, offsets);
    }
    return attacks;
}

pub fn rays(comptime bishop_offs: []const i32, comptime rook_offs: []const i32) [64][64]Bitboard {
    comptime var rs: [64][64]Bitboard = undefined;
    comptime var i: usize = 0;
    // from each square to each square - i is the starting square
    while (i < 64) : (i += 1) {
        const start_sq = square.fromInt(usize, i);
        comptime var bishop_attack = attack(start_sq, bitboard.empty, bishop_offs);
        comptime var rook_attack = attack(start_sq, bitboard.empty, rook_offs);
        while (bishop_attack.next()) |next_sq| {
            const start_bb = attack(start_sq, bitboard.empty, bishop_offs);
            const next_bb = attack(next_sq, bitboard.empty, bishop_offs);
            rs[i][next_sq.index()] = start_bb.bitand(next_bb).bitor(start_sq.toBitboard()).bitor(next_sq.toBitboard());
        }

        while (rook_attack.next()) |next_sq| {
            const start_bb = attack(start_sq, bitboard.empty, rook_offs);
            const next_bb = attack(next_sq, bitboard.empty, rook_offs);
            rs[i][next_sq.index()] = start_bb.bitand(next_bb).bitor(start_sq.toBitboard()).bitor(next_sq.toBitboard());
        }
    }
    return rs;
}
