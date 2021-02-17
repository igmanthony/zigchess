const print = @import("std").debug.print;
const color = @import("color.zig");
const square = @import("square.zig");
const Square = square.Square;
const Color = color.Color;

pub const Bitboard = packed struct {
    bits: u64,

    pub fn debug(self: Bitboard) void {
        print("{s}\n", .{self.toString()});
    }

    pub fn eq(self: Bitboard, other: Bitboard) callconv(.Inline) bool {
        return self.bits == other.bits;
    }

    pub fn contains(self: Bitboard, sq: Square) callconv(.Inline) bool {
        return ((self.bits >> sq.index()) & 1) > 0;
    }

    pub fn isEmpty(self: Bitboard) callconv(.Inline) bool {
        return self.bits == 0;
    }

    pub fn isNotEmpty(self: Bitboard) callconv(.Inline) bool {
        return self.bits != 0;
    }

    pub fn isOneSquare(self: Bitboard) callconv(.Inline) bool {
        return (self.bits & (self.bits -% 1) == 0) and (self.isNotEmpty());
        // return count(self) == 1;
    }

    // pub fn isMultiple(self: Bitboard) callconv(.Inline) bool {
    //     return (self.bits & self.bits -% 1) != 0;
    // }

    pub fn count(self: Bitboard) callconv(.Inline) u64 {
        return @popCount(u64, self.bits);
    }

    pub fn toString(self: Bitboard) [72]u8 {
        var string: [72]u8 = undefined;
        for (string) |*val, i| {
            const f: usize = i % 9;
            const r: usize = (71 - i) / 9;
            if (f == 8) {
                val.* = '\n';
            } else if (self.contains(square.fromInt(usize, f | (r << 3)).?)) {
                val.* = '+';
            } else {
                val.* = '.';
            }
        }
        return string;
    }

    pub fn first(self: Bitboard) callconv(.Inline) ?Square {
        return if (self.isNotEmpty()) square.fromIndex(@intCast(u6, @ctz(u64, self.bits))) else null;
    }

    // pub fn last(self: Bitboard) callconv(.Inline) ?Square {
    //     return if (self.isNotEmpty()) square.tryFromInt(u64, 63 - @clz(u64, self.bits)) else null;
    // }

    // converts bitboard to a square iff there is a single bit set
    pub fn toSquare(self: Bitboard) callconv(.Inline) ?Square {
        return if (self.isOneSquare()) self.first() else null;
    }

    pub fn addSquare(self: Bitboard, sq: Square) callconv(.Inline) Bitboard {
        return Bitboard{ .bits = (self.bits | sq.toBitboard().bits) };
    }

    pub fn relativeShift(self: Bitboard, clr: Color, shift: u6) callconv(.Inline) Bitboard {
        return switch (clr) {
            .white => Bitboard{ .bits = (self.bits << shift) },
            .black => Bitboard{ .bits = (self.bits >> shift) },
        };
    }

    pub fn copy(self: Bitboard) callconv(.Inline) Bitboard {
        return Bitboard{ .bits = self.bits };
    }

    pub fn invert(self: Bitboard) callconv(.Inline) Bitboard {
        return Bitboard{ .bits = ~self.bits };
    }

    pub fn bitand(self: Bitboard, other: Bitboard) callconv(.Inline) Bitboard {
        return Bitboard{ .bits = self.bits & other.bits };
    }

    pub fn bitxor(self: Bitboard, other: Bitboard) callconv(.Inline) Bitboard {
        return Bitboard{ .bits = self.bits ^ other.bits };
    }

    pub fn bitor(self: Bitboard, other: Bitboard) callconv(.Inline) Bitboard {
        return Bitboard{ .bits = self.bits | other.bits };
    }

    pub fn toggle(self: *Bitboard, sq: Square) callconv(.Inline) void {
        self.bits ^= (sq.toBitboard().bits);
    }

    pub fn clearBit(self: *Bitboard, sq: Square) callconv(.Inline) void {
        self.bits &= (~sq.toBitboard().bits);
    }

    pub fn clearBits(self: *Bitboard, bits: Bitboard) callconv(.Inline) void {
        self.bits &= (~bits.bits);
    }

    pub fn setBit(self: *Bitboard, sq: Square) callconv(.Inline) void {
        self.bits |= (sq.toBitboard().bits);
        // self.bits ^= (sq.toBitboard().bits);
    }

    pub fn setBits(self: *Bitboard, bits: Bitboard) callconv(.Inline) void {
        self.bits |= bits.bits;
    }

    /// Brian Kernighan's method for pop front bit see chessprogramming.org/Bitboard_Serialization
    pub fn next(self: *Bitboard) callconv(.Inline) ?Square {
        if (self.first()) |sq| {
            self.bits &= (self.bits -% 1);
            return sq;
        } else {
            return null;
        }
    }
};

/// associated constants and functions;
pub const empty = new(0);
pub const all = not(0);
pub const dark_squares = new(0xaa55_aa55_aa55_aa55);
pub const light_squares = new(0x55aa_55aa_55aa_55aa);
pub const corners = new(0x8100_0000_0000_0081);
pub const back_ranks = new(0xff00_0000_0000_00ff);
pub const center = new(0x0000_0018_1800_0000);
pub const king_path = new(0x6c00_0000_0000_006c); // king castle paths
pub const rook_path = new(0x6e00_0000_0000_006e); // rook castle paths
pub const king_castle = new(0x4400_0000_0000_0044); // where the king ends up castling to
pub const rook_castle = new(0x2800_0000_0000_0028); // where the rook ends up castling to

pub const kingside = new(0xf0f0_f0f0_f0f0_f0f0);
pub const queenside = new(0x0f0f_0f0f_0f0f_0f0f);

pub const ranks = [8]Bitboard{
    new(0x0000_0000_0000_00ff), new(0x0000_0000_0000_ff00),
    new(0x0000_0000_00ff_0000), new(0x0000_0000_ff00_0000),
    new(0x0000_00ff_0000_0000), new(0x0000_ff00_0000_0000),
    new(0x00ff_0000_0000_0000), new(0xff00_0000_0000_0000),
};

pub const files = [8]Bitboard{
    new(0x0101_0101_0101_0101), new(0x0202_0202_0202_0202),
    new(0x0404_0404_0404_0404), new(0x0808_0808_0808_0808),
    new(0x1010_1010_1010_1010), new(0x2020_2020_2020_2020),
    new(0x4040_4040_4040_4040), new(0x8080_8080_8080_8080),
};

pub fn not(number: u64) callconv(.Inline) Bitboard {
    return Bitboard{ .bits = ~number };
}

pub fn new(number: u64) callconv(.Inline) Bitboard {
    return Bitboard{ .bits = number };
}

pub fn rank(r: usize) callconv(.Inline) Bitboard {
    return ranks[r];
}

pub fn file(f: usize) callconv(.Inline) Bitboard {
    return files[f];
}

pub fn relativeRank(clr: Color, r: usize) callconv(.Inline) Bitboard {
    return rank(clr.wlbr(usize, r, 7 - r));
}
