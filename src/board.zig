const print = @import("std").debug.print;

const attack = @import("attack.zig");
const bitboard = @import("bitboard.zig");
const color = @import("color.zig");
const errors = @import("errors.zig");
const piece = @import("piece.zig");
const square = @import("square.zig");
const Bitboard = bitboard.Bitboard;
const Color = color.Color;
const white = Color.white;
const black = Color.black;
const Square = square.Square;
const Piece = piece.Piece;
const PieceType = piece.PieceType;

/// Collection of bitboards that show the "visual" state of the board. The information contained
/// in an unattended chess board. Castling rights, 50-move rule, 3-fold repetition,
/// en passant, and whose turn it is to move are not obvious or unambiguous.
/// A property of this representation is that xoring all pieces (+ empty) or both colors (+ empty)
/// should give a full board with all bits active.
pub const Board = struct {
    empty: Bitboard,
    pawns: Bitboard,
    knights: Bitboard,
    bishops: Bitboard,
    rooks: Bitboard,
    queens: Bitboard,
    kings: Bitboard,
    white: Bitboard,
    black: Bitboard,

    pub fn pieceTypeOn(self: Board, sq: Square) callconv(.Inline) !PieceType {
        if (sq.in(self.empty)) {
            return PieceType.empty;
        } else if (sq.in(self.pawns)) {
            return PieceType.pawn;
        } else if (sq.in(self.knights)) {
            return PieceType.knight;
        } else if (sq.in(self.bishops)) {
            return PieceType.bishop;
        } else if (sq.in(self.rooks)) {
            return PieceType.rook;
        } else if (sq.in(self.queens)) {
            return PieceType.queen;
        } else if (sq.in(self.kings)) {
            return PieceType.king;
        } else {
            return errors.ChessError.InvalidBoard; // valid boards should have some "type"
        }
    }

    pub fn pieceOn(self: Board, sq: Square) callconv(.Inline) !?Piece {
        return Piece{
            .color = if (sq.in(self.white)) white else if (sq.in(self.black)) black else return null,
            .piece_type = try pieceTypeOn(self, sq),
        };
    }

    pub fn ofColor(self: Board, clr: Color) callconv(.Inline) Bitboard {
        return switch (clr) {
            .white => self.white,
            .black => self.black,
        };
    }

    pub fn ofPieceType(self: Board, piece_type: PieceType) callconv(.Inline) Bitboard {
        return switch (piece_type) {
            .pawn => self.pawns,
            .knight => self.knights,
            .bishop => self.bishops,
            .rook => self.rooks,
            .queen => self.queens,
            .king => self.kings,
            .empty => self.empty,
            .other => unreachable,
        };
    }

    pub fn ofPiece(self: Board, pce: Piece) callconv(.Inline) Bitboard {
        return self.ofPieceType(pce.piece_type).bitand(self.ofColor(pce.color));
    }

    pub fn occupied(self: Board) callconv(.Inline) Bitboard {
        return self.empty.invert();
    }

    pub fn sliders(self: Board) callconv(.Inline) Bitboard {
        return Bitboard{ .bits = self.bishops.bits ^ self.rooks.bits ^ self.queens.bits };
    }

    /// calculates bitboard of pieces attacking the active player's king
    /// assumes only one king of each color; this shouldn't be called much -> use the position's
    /// checkers field.
    pub fn checkers(self: Board, player: Color) callconv(.Inline) Bitboard {
        const king: Square = self.ofPiece(Piece{ .piece_type = PieceType.king, .color = player }).toSquare().?;
        return self.attackersOf(king, player.invert());
    }

    pub fn sliderBlockers(self: Board, enemies: Bitboard, king: Square) callconv(.Inline) Bitboard {
        const r = attack.rookFrom(king, bitboard.empty).bitand(self.rooks.bitxor(self.queens));
        const b = attack.bishopFrom(king, bitboard.empty).bitand(self.bishops.bitxor(self.queens));
        const snipers = r.bitor(b);
        var blockers = bitboard.empty;
        var sniper_enemies = snipers.bitand(enemies);
        while (sniper_enemies.next()) |sniper| {
            const blocker = attack.between(king, sniper).bitand(self.occupied());
            if (blocker.isOneSquare()) {
                blockers = blockers.bitor(blocker);
            }
        }
        return blockers;
    }

    pub fn attackersOf(self: Board, sq: Square, attacker: Color) callconv(.Inline) Bitboard {
        // the "occupied" parameter to the bishop and rook steps was oritinally a parameter
        // to pass through the function... but seemed to only ever be "occupied"
        const other = self.ofColor(attacker);
        const rq = attack.rookFrom(sq, self.occupied()).bitand(self.rooks.bitor(self.queens));
        const bq = attack.bishopFrom(sq, self.occupied()).bitand(self.bishops.bitor(self.queens));
        const n = attack.knightFrom(sq).bitand(self.knights);
        const k = attack.kingFrom(sq).bitand(self.kings);
        const p = attack.pawnFrom(attacker.invert(), sq).bitand(self.pawns);
        return other.bitand(rq.bitor(bq).bitor(n).bitor(k).bitor(p));
    }

    pub fn debug(self: Board) ![72:0]u8 {
        var string: [72:0]u8 = undefined;
        for (string) |*val, i| {
            const f: usize = i % 9;
            const r: usize = (71 - i) / 9;
            if (f == 8) {
                val.* = '\n';
            } else {
                const p = try self.pieceOn(Square{
                    .rank = @intCast(u3, r),
                    .file = @intCast(u3, f),
                });
                val.* = if (p == null) '.' else p.?.toChar();
            }
        }
        return string;
    }

    pub fn removeOn(self: *Board, sq: Square) callconv(.Inline) void {
        self.pawns.clearBit(sq);
        self.knights.clearBit(sq);
        self.bishops.clearBit(sq);
        self.rooks.clearBit(sq);
        self.queens.clearBit(sq);
        self.kings.clearBit(sq);
        self.empty.setBit(sq);
        self.white.clearBit(sq);
        self.black.clearBit(sq);
    }

    pub fn setPieceOn(self: *Board, pce: Piece, sq: Square) callconv(.Inline) void {
        self.removeOn(sq);
        switch (pce.color) {
            .white => self.white.setBit(sq),
            .black => self.black.setBit(sq),
        }
        switch (pce.piece_type) {
            .pawn => self.pawns.setBit(sq),
            .knight => self.knights.setBit(sq),
            .bishop => self.bishops.setBit(sq),
            .rook => self.rooks.setBit(sq),
            .queen => self.queens.setBit(sq),
            .king => self.kings.setBit(sq),
            .empty => unreachable,
            .other => unreachable,
        }
        self.empty.clearBit(sq);
    }
};

/// the standard chess starting position
pub fn standard() Board {
    return Board{
        .pawns = Bitboard{ .bits = 0x00ff_0000_0000_ff00 },
        .knights = Bitboard{ .bits = 0x4200_0000_0000_0042 },
        .bishops = Bitboard{ .bits = 0x2400_0000_0000_0024 },
        .rooks = Bitboard{ .bits = 0x8100_0000_0000_0081 },
        .queens = Bitboard{ .bits = 0x0800_0000_0000_0008 },
        .kings = Bitboard{ .bits = 0x1000_0000_0000_0010 },
        .white = Bitboard{ .bits = 0x0000_0000_0000_ffff },
        .black = Bitboard{ .bits = 0xffff_0000_0000_0000 },
        .empty = Bitboard{ .bits = 0x0000_ffff_ffff_0000 },
    };
}

pub fn empty() Board {
    return Board{
        .pawns = Bitboard{ .bits = 0 },
        .knights = Bitboard{ .bits = 0 },
        .bishops = Bitboard{ .bits = 0 },
        .rooks = Bitboard{ .bits = 0 },
        .queens = Bitboard{ .bits = 0 },
        .kings = Bitboard{ .bits = 0 },
        .white = Bitboard{ .bits = 0 },
        .black = Bitboard{ .bits = 0 },
        .empty = bitboard.all,
    };
}

/// Checks if the pieces can actually be on the board in this configuration
/// doesn't check any chess rules - just that the board is fully described and
/// unambiguously showing the position of the pieces
pub fn isLegal(b: Board) bool {
    const tmp = b.pawns.bitor(b.knights).bitor(b.kings);
    const pieces = tmp.bitor(b.bishops).bitor(b.rooks).bitor(b.queens);
    const colors = b.white.bitor(b.black);
    const pieces_eq_colors = pieces.eq(colors);
    const pieces_eq_not_empty = pieces.eq(b.empty.invert());
    const all_squares_covered = pieces.bitor(b.empty).eq(bitboard.all);
    return pieces_eq_colors and pieces_eq_not_empty and all_squares_covered;
}
