const color = @import("color.zig");
const piece = @import("piece.zig");
const square = @import("square.zig");
const errors = @import("errors.zig");
const position = @import("position.zig");
const bitboard = @import("bitboard.zig");
const Bitboard = bitboard.Bitboard;
const Position = position.Position;
const Color = color.Color;
const PieceType = piece.PieceType;
const Square = square.Square;

/// TODO: Figure out how to make Move a packed struct; I think I can do away with the result
/// The only reason I can think to keep it is for easier checking of half move clock - otherwise,
/// we clear the square that the mover moves to regardless.
///
/// From and To always denote the start and end squares. If they are the same square, then
/// the move was passed (illegal in standard chess, but sometimes useful for engines to swap
/// the actively-moving player
///
/// * If the "special" flag is false, then the "mover" and "result" indicate the normal movements of
///   pieces with "result" indicating a capture piece or "empty" if no piece was captured
/// * If the "special" flag is true, then a special king or pawn move occured:
///
///        mover | result | special move
///        ----- | ------ | ------------
///        king  | queen  | queenside castles
///        king  | king   | kingside castles
///        pawn  | pawn   | en passant capture of pawn
///        pawn  | empty  | pawn double move
///        nrbq  | nrbq   | pawn promoted to mover (nrbq) and took result piece (nrbq)
///        nrbq  | empty  | pawn promoted to mover (nrbq) without taking a piece
/// ** nrbq = Knight, Rook, Bishop, Queen
///
/// Struct for holding move information
pub const Move = struct { // This should be packed struct but failes with a weird, silent error
    from: Square, // 6 bits
    to: Square, // 6 bits
    special: bool, // 1 bit
    mover: PieceType, // 3 bits (3: type, 1: color)
    result: PieceType, // 3 bits
    // evaluation: i13 // +- 4095.
    // 6 + 6 + 1 + 3 + 3 + 13 = 32 bits total

    pub fn new(from: Square, to: Square, special: bool, mover: PieceType, result: PieceType) callconv(.Inline) Move {
        return Move{ .from = from, .to = to, .special = special, .mover = mover, .result = result };
    }

    pub fn resetsHalfMoveClock(self: Move) callconv(.Inline) bool {
        return ((self.special) or (self.mover == PieceType.pawn) or (self.result != PieceType.empty));
    }

    pub fn isCapture(self: Move) callconv(.Inline) bool {
        return !((self.result == PieceType.empty) or ((self.mover == PieceType.king) and self.special));
    }


    // pub fn toString(self: Move) [11]u8 {
    //     var string = [1]u8{' '} ** 11;
    //     string[0] = if (self.special) '+' else ' ';
    //     string[2] = self.mover.toChar();
    //     var s1 = string[3..5];
    //     s1.* = self.from.toString();
    //     var s2 = string[6..8];
    //     s2.* = self.to.toString();
    //     string[10] = self.result.toChar();
    //     return string;
    // }

    pub fn toString(self: Move) [11]u8 {
        var string = [1]u8{' '} ** 11;
        string[0] = if (self.special) '$' else ' ';
        if (!self.special and self.result != PieceType.empty) {
            string[1] = self.mover.toChar();
            string[2] = 'x';
            var s3 = string[3..5];
            s3.* = self.to.toString();
        } else {
            string[2] = self.mover.toChar();
            var s3 = string[3..5];
            s3.* = self.to.toString();
        }
        // var s1 = string[3..5];
        // s1.* = self.from.toString();
        // var s2 = string[6..8];
        // s2.* = self.to.toString();
        // string[10] = self.result.toChar();
        return string;
    }
};

// The number of legal chess moves in a single position should never exceed 218, see FEN:
// R6R/3Q4/1Q4Q1/4Q3/2Q4Q/Q4Q2/pp1Q4/kBNN1KB1 w - - 0 1
pub const MoveList = struct {
    len: usize,
    items: [128]Move, // hopefully we don't exceed this!

    pub fn new() MoveList {
        return MoveList{ .items = undefined, .len = 0 };
    }

    pub fn isEmpty(self: MoveList) callconv(.Inline) bool {
        return self.len == 0;
    }

    pub fn remainingCapacity(self: MoveList) callconv(.Inline) usize {
        return self.items.len - self.len;
    }

    pub fn constSlice(self: MoveList) []const Move {
        return self.items[0..self.len];
    }

    pub fn slice(self: *MoveList) []Move {
        return self.items[0..self.len];
    }

    pub fn clear(self: *MoveList) void {
        self.len = 0;
    }

    pub fn push(self: *MoveList, new_move: Move) callconv(.Inline) errors.ChessError!void {
        if (self.len < self.items.len) {
            // @setRuntimeSafety(false);
            const self_len = self.len;
            self.items[self_len] = new_move;
            self.len = (self_len + 1);
        } else {
            return errors.ChessError.CapacityError;
        }
    }

    pub fn pop(self: *MoveList) callconv(.Inline) ?Move {
        if (!self.isEmpty()) {
            // @setRuntimeSafety(false);
            // const new_len = self.len - 1;
            // self.len = new_len;
            // return self.items[new_len];
            self.len -= 1;
            return self.items[self.len];
        } else {
            return null;
        }
    }

    /// Aliases pop for iteration
    pub fn next(self: *MoveList) callconv(.Inline) ?Move {
        return self.pop();
    }

    /// appends a MoveList slice or normal slice of moves onto the MoveList
    pub fn append(self: *MoveList, other: []const Move) callconv(.Inline) !void {
        if (self.remainingCapacity() >= other.len) {
            // @setRuntimeSafety(false);
            for (other) |o, i| {
                self.items[self.len..][i] = o;
            }
            self.len = self.len + other.len;
        } else {
            return errors.ChessError.CapacityError;
        }
    }

    // /// remove moves that return "false" to a generic movecheck function
    // // const movecheck = fn (*Move, anytype, anytype, anytype) bool
    // const movecheck = fn (*Move, anytype, anytype, anytype) bool;
    // pub fn filter(self: *MoveList, func: movecheck, anytype, anytype, anytype) void {
    //     var i: usize = 0;
    //     while (i < self.len) {
    //         if (func(&self.items[i], anytype, anytype, anytype)) {
    //             i += 1;
    //         } else {
    //             _ = self.swapRemove(i);
    //         }
    //     }
    // }

    pub fn swapRemove(self: *MoveList, i: usize) callconv(.Inline) ?Move {
        if (self.items.len - 1 == i) return self.pop();
        const old_item = self.items[i];
        self.items[i] = self.pop().?;
        return old_item;
    }

    // pub fn swapRemove(self: *MoveList, i: usize) callconv(.Inline) void {
    //     if (self.items.len - 1 == i) {
    //         _ = self.pop();
    //     } else {
    //         self.items[i] = self.pop().?;
    //     }
    // }
};
