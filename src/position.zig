const print = @import("std").debug.print;

const attack = @import("attack.zig");
const bitboard = @import("bitboard.zig");
const board = @import("board.zig");
const color = @import("color.zig");
const move = @import("move.zig");
const piece = @import("piece.zig");
const square = @import("square.zig");
const Bitboard = bitboard.Bitboard;
const Board = board.Board;
const Color = color.Color;
const Move = move.Move;
const MoveList = move.MoveList;
const Square = square.Square;
const PieceType = piece.PieceType;
const Piece = piece.Piece;

pub const Position = struct {
    board: Board, // The state of the board
    color: Color, // Player to move
    castles: Bitboard, // mask of rook corner squares to denote castling rights
    en_passant: ?Square = null, // The square behind the pawn that double moved (may or may not be enpassant)
    halfmove_clock: u6 = 0, // Moves since last pawn push or piece capture - 50 move rule
    fullmove_number: u10 = 0, // total moves
    checkers: Bitboard = bitboard.empty, // mask of pieces checking the king

    pub fn us(self: Position) callconv(.Inline) Bitboard {
        return self.board.ofColor(self.color);
    }

    pub fn our(self: Position, piece_type: PieceType) callconv(.Inline) Bitboard {
        return self.us().bitand(self.board.ofPieceType(piece_type));
    }

    pub fn them(self: Position) callconv(.Inline) Bitboard {
        return self.board.ofColor(self.theirColor());
    }

    pub fn their(self: Position, piece_type: PieceType) callconv(.Inline) Bitboard {
        return self.them().bitand(self.board.ofPieceType(piece_type));
    }

    pub fn theirColor(self: Position) callconv(.Inline) Color {
        return self.color.invert();
    }

    pub fn isCheck(self: Position) callconv(.Inline) bool {
        return self.checkers.isNotEmpty();
    }

    fn isCheckmate(self: *Position) bool { // needed?
        return (self.isCheck() and (self.legalMoves().len == 0));
    }

    fn isStalemate(self: *Position) bool { // needed?
        return (!self.isCheck() and (self.legalMoves().len == 0));
    }

    fn insufficentMaterial(self: Position) bool {
        const b = self.board;
        const bls = bitboard.light_squares;
        const bds = bitboard.dark_squares;
        if ((b.pawns.bitand(b.rooks).bitand(b.queens)).isNotEmpty()) {
            return false; // any pawns, rooks, or queens are always sufficient for mate
        } else if ((b.knights.count() > 1) or (b.bishops.count() > 2)) {
            return false; // More than a single knight or two bishops can cause mate
        } else if (b.knights.isOneSquare() and b.bishops.isOneSquare()) {
            return false; // a single knight and a single bishop can cause a mate
        } else if ((b.bishops.bitand(bds).count() > 1) and (b.bishops.bitand(bls) > 1)) {
            return false; // a dark and light squared bishop can lead to mate
        } else {
            return true; // Insufficient material = a stalemate (draw)
        }
    }

    pub fn playMove(self: *Position, m: Move) callconv(.Inline) void {
        // if m.isEnPassant() 
        self.en_passant = null; // reset en passant square
        const back = bitboard.relativeRank(self.color, 0);
        const king_side = (m.from.toBitboard().bitand(bitboard.kingside)).isNotEmpty();
        const back_side = back.bitand(if (king_side) bitboard.kingside else bitboard.queenside);
        if (m.mover == PieceType.king) {
            self.castles = self.castles.bitand(back.invert());
            if (m.special) {
                self.board.removeOn(back_side.bitand(bitboard.corners).toSquare().?);
                const rook = back_side.bitand(bitboard.rook_castle).toSquare().?;
                self.board.setPieceOn(Piece{ .piece_type = PieceType.rook, .color = self.color }, rook);
            }
        } 
        if (m.special and m.mover == PieceType.pawn) { // separating these as if statements improves performance
            if (m.result == PieceType.pawn) {
                self.board.removeOn(Square{ .file = m.to.file, .rank = m.from.rank });
            } else if (m.result == PieceType.empty) {
                self.en_passant = Square{ .rank = self.color.wlbr(u3, 2, 5), .file = m.from.file };
            }
        }
        self.castles.clearBit(m.from);
        self.castles.clearBit(m.to); // if we ever move to a castles square, clear it permanently
        self.board.removeOn(m.from); // no matter what, we move away from a square and to a square
        self.board.setPieceOn(Piece{ .piece_type = m.mover, .color = self.color }, m.to);
        self.halfmove_clock = if (m.resetsHalfMoveClock()) 0 else self.halfmove_clock + 1;
        self.fullmove_number += self.color.wlbr(u10, 0, 1);
        self.color = self.color.invert();
        self.checkers = self.board.checkers(self.color); // calculate new checkers for new player
    }

    pub fn clone(self: Position) Position {
        return Position{
            .board = self.board,
            .color = self.color,
            .castles = self.castles,
            .en_passant = self.en_passant,
            .halfmove_clock = self.halfmove_clock,
            .fullmove_number = self.fullmove_number,
            .checkers = self.checkers,
        };
    }
};

/// sets up the standard chess position
pub fn standard() Position {
    return Position{
        .board = board.standard(),
        .color = Color.white,
        .castles = bitboard.corners,
    };
}
