/// Setup module to generate attacking bitboards; this should eventually become comptime
/// when compile times improve or when I really want to release
const expect = @import("std").testing.expect;
const bitboard = @import("bitboard.zig");
const magic = @import("magic.zig");
const square = @import("square.zig");
const Bitboard = bitboard.Bitboard;
const Square = square.Square;

pub const rook_shift: usize = 12;
pub const bishop_shift: usize = 9;

/// so instead of 'comptime' for all these, due to long compile times we'll make them run-time
/// calculated in an 'init' function. We'll just need to call the 'init' function once in main
/// to initalize all these global variables
pub var white_pawn_attacks: [64]Bitboard = undefined;
pub var black_pawn_attacks: [64]Bitboard = undefined;
pub var knight_attacks: [64]Bitboard = undefined;
pub var king_attacks: [64]Bitboard = undefined;
pub var rook_bishop_attacks: [88_772]Bitboard = undefined;
pub var rook_bishop_rays: [64][64]Bitboard = undefined;

pub fn init() void {
    white_pawn_attacks = basicAttack(&white_pawn_offsets);
    black_pawn_attacks = basicAttack(&black_pawn_offsets);
    knight_attacks = basicAttack(&knight_offsets);
    king_attacks = basicAttack(&king_offsets);
    rook_bishop_attacks = slidingAttack(&bishop_offsets, &rook_offsets);
    rook_bishop_rays = rays(&bishop_offsets, &rook_offsets);
}

// Compiletime stuff would go below

// single-square movement offsets of pieces
const white_pawn_offsets = [2]i32{ 7, 9 };
const black_pawn_offsets = [2]i32{ -7, -9 };
const knight_offsets = [8]i32{ 17, 15, 10, 6, -17, -15, -10, -6 };
const bishop_offsets = [4]i32{ 9, 7, -9, -7 };
const rook_offsets = [4]i32{ 8, 1, -8, -1 };
const king_offsets = [8]i32{ 9, 8, 7, 1, -9, -8, -7, -1 };

/// Carry-Rippler subset traversal, see chessprogramming.org/Traversing_Subsets_of_a_Set
const CarryRippler = struct {
    mask: u64, // mask is static throughout the Carry-Rippler iteration
    subset: u64,
    initial: bool,

    fn next(self: *CarryRippler) ?Bitboard {
        if ((self.subset != 0) or self.initial) {
            const sub = self.subset;
            self.*.initial = false;
            self.*.subset = (self.subset -% self.mask) & self.mask; // Carry-Rippler expression
            return Bitboard{ .bits = self.subset };
        } else {
            return null;
        }
    }
};

fn attack(sq: Square, occupied: Bitboard, offsets: []const i32) Bitboard {
    // @setEvalBranchQuota(1_000_000); // default of 1_000 is not enough for this const function;
    var atk = bitboard.empty;
    var i: usize = 0;
    while (i < offsets.len) : (i += 1) {
        var previous = sq;
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

fn basicAttack(offsets: []const i32) [64]Bitboard {
    var attacks: [64]Bitboard = undefined;
    for (attacks) |*atk, i| {
        atk.* = attack(square.fromInt(usize, i).?, bitboard.all, offsets);
    }
    return attacks;
}

fn slidingAttack(bishop_offs: []const i32, rook_offs: []const i32) [88_772]Bitboard {
    var attacks: [88_772]Bitboard = [_]Bitboard{bitboard.empty} ** 88_772;
    var i: u8 = 0;
    while (i < 64) : (i += 1) {
        const sq = square.fromInt(u8, i).?;
        const r_magic = magic.rook[i];
        const b_magic = magic.bishop[i];
        var r_carry_rippler = CarryRippler{ .mask = r_magic.mask, .subset = 0, .initial = true };
        var b_carry_rippler = CarryRippler{ .mask = b_magic.mask, .subset = 0, .initial = true };
        while (r_carry_rippler.next()) |subset| {
            const index = ((r_magic.factor *% subset.bits) >> (64 - rook_shift)) + r_magic.offset;
            attacks[index] = attack(sq, subset, rook_offs);
        }
        while (b_carry_rippler.next()) |subset| {
            const index = ((b_magic.factor *% subset.bits) >> (64 - bishop_shift)) + b_magic.offset;
            attacks[index] = attack(sq, subset, bishop_offs);
        }
    }
    return attacks;
}

fn rays(bishop_offs: []const i32, rook_offs: []const i32) [64][64]Bitboard {
    var rs: [64][64]Bitboard = [_][64]Bitboard{[_]Bitboard{bitboard.empty} ** 64} ** 64;
    var i: u8 = 0;
    // from each square to each square - i is the starting square index
    while (i < 64) : (i += 1) {
        const start_sq = square.fromInt(u8, i).?;
        var bishop_attack = attack(start_sq, bitboard.empty, bishop_offs);
        var rook_attack = attack(start_sq, bitboard.empty, rook_offs);
        while (bishop_attack.next()) |next_sq| {
            const start_bb = attack(start_sq, Bitboard{ .bits = 0 }, bishop_offs);
            const next_bb = attack(next_sq, Bitboard{ .bits = 0 }, bishop_offs);
            // I'm not sure whether it's better to chain function calls or to access 'bits' directly
            // rs[i][next_sq.index()] = start_bb.bitand(next_bb).bitor(start_sq.toBitboard()).bitor(next_sq.toBitboard());
            rs[i][next_sq.index()] = Bitboard{ .bits = start_bb.bits & next_bb.bits | start_sq.toBitboard().bits | next_sq.toBitboard().bits };
        }
        while (rook_attack.next()) |next_sq| {
            const start_bb = attack(start_sq, bitboard.empty, rook_offs);
            const next_bb = attack(next_sq, bitboard.empty, rook_offs);
            rs[i][next_sq.index()] = start_bb.bitand(next_bb).bitor(start_sq.toBitboard()).bitor(next_sq.toBitboard());
        }
    }
    return rs;
}
