const expect = @import("std").testing.expect;
const bitboard = @import("bitboard.zig");
const color = @import("color.zig");
const piece = @import("piece.zig");
const magic = @import("magic.zig");
const setup = @import("setup.zig");
const square = @import("square.zig");
const Bitboard = bitboard.Bitboard;
const Color = color.Color;
const Piece = piece.Piece;
const Square = square.Square;

/// general lookup functions for squares that produce attacking bitboards
pub fn pawnFrom(clr: Color, sq: Square) callconv(.Inline) Bitboard {
    return switch (clr) {
        .white => setup.white_pawn_attacks[sq.index()],
        .black => setup.black_pawn_attacks[sq.index()],
    };
}

pub fn knightFrom(sq: Square) callconv(.Inline) Bitboard {
    return setup.knight_attacks[sq.index()];
}

pub fn bishopFrom(sq: Square, occupied: Bitboard) callconv(.Inline) Bitboard {
    const m = magic.bishop[sq.index()];
    const i = ((m.factor *% (occupied.bits & m.mask)) >> (64 - setup.bishop_shift)) + m.offset;
    return setup.rook_bishop_attacks[i];
}

pub fn rookFrom(sq: Square, occupied: Bitboard) callconv(.Inline) Bitboard {
    const m = magic.rook[sq.index()];
    const i = ((m.factor *% (occupied.bits & m.mask)) >> (64 - setup.rook_shift)) + m.offset;
    return setup.rook_bishop_attacks[i];
}

pub fn queenFrom(sq: Square, occupied: Bitboard) callconv(.Inline) Bitboard {
    // why is this exclusive or?
    return rookFrom(sq, occupied).bitxor(bishopFrom(sq, occupied));
}

pub fn kingFrom(sq: Square) callconv(.Inline) Bitboard {
    return setup.king_attacks[sq.index()];
}

/// this just calls the individual xFrom functions above for a piece
pub fn pieceFrom(sq: Square, pce: Piece, occupied: Bitboard) callconv(.Inline) Bitboard {
    return switch (pce.piece_type) {
        .pawn => pawnFrom(pce.color, sq),
        .knight => knightFrom(sq),
        .bishop => bishopFrom(sq, occupied),
        .rook => rookFrom(sq, occupied),
        .queen => queenFrom(sq, occupied),
        .king => kingFrom(sq),
        .empty => bitboard.empty,
        .other => unreachable,
    };
}

// pub fn bishopMask(sq: Square) Bitboard {
//     return Bitboard{ .bits = magic.bishop[sq.index()].mask };
// }

// pub fn rookMask(sq: Square) Bitboard {
//     return Bitboard{ .bits = magic.rook[sq.index()].mask };
// }

pub fn ray(from: Square, to: Square) callconv(.Inline) Bitboard {
    return setup.rook_bishop_rays[from.index()][to.index()];
}

pub fn aligned(a: Square, b: Square, c: Square) callconv(.Inline) bool {
    return ray(a, b).contains(c);
}

pub fn between(a: Square, b: Square) callconv(.Inline) Bitboard {
    const bits = ray(a, b).bits & ((bitboard.all.bits << a.index()) ^ (bitboard.all.bits << b.index()));
    return Bitboard{ .bits = bits & (bits -% 1) };
}
