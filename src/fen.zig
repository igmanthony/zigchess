const std = @import("std");
const tokenize = std.mem.tokenize;
const print = std.debug.print;

const bitboard = @import("bitboard.zig");
const board = @import("board.zig");
const color = @import("color.zig");
const errors = @import("errors.zig");
const piece = @import("piece.zig");
const position = @import("position.zig");
const square = @import("square.zig");
const Bitboard = bitboard.Bitboard;
const Board = board.Board;
const Square = square.Square;
const Piece = piece.Piece;
const Position = position.Position;
const InvalidASCII = errors.ChessError.InvalidASCII;

/// so this will only parse ideal ascii FENs - nothing can be out of spec
/// FENs have 6 parts - board, color, castles, en passant, halfmove clock, fullmove counter
pub fn ascii(fen: []const u8) !Position {
    var split = Fenerator{ .fen = fen, .delimiter = ' ' };
    const board_fen = split.next() orelse return InvalidASCII;
    const color_fen = split.next() orelse return InvalidASCII;
    const castles_fen = split.next() orelse return InvalidASCII;
    const en_passant_fen = split.next() orelse return InvalidASCII;
    // const halfmove_clock_fen = split.next() orelse return InvalidASCII;
    // const fullmove_number_fen = split.next() orelse return InvalidASCII;
    // const hmc = try parseNumber(halfmove_clock_fen);
    const board_parsed = try parseBoard(board_fen);
    const color_parsed = color.fromChar(color_fen[0]) orelse return InvalidASCII;
    return Position{
        .board = board_parsed,
        .color = color_parsed,
        .castles = try parseCastleRights(castles_fen),
        .en_passant = try square.fromNotation(en_passant_fen),
        // .halfmove_clock = if (hmc < 51) @intCast(u6, hmc) else return InvalidASCII,
        // .fullmove_number = try parseNumber(fullmove_number_fen),
        .checkers = board_parsed.checkers(color_parsed),
    };
}

pub fn parseBoard(fen: []const u8) !Board {
    var rank: i16 = 7;
    var file: i16 = 0;
    var fen_board = board.empty();
    var iter_board = Fenerator{ .fen = fen, .delimiter = '/' };
    while (iter_board.next()) |r| {
        if ((rank < 0) or (file > 7)) return InvalidASCII;
        for (r) |char| {
            const sq = Square{ .rank = @intCast(u3, rank), .file = @intCast(u3, file) };
            switch (char) {
                '0'...'9' => file += (char - '0'),
                else => {
                    const pce = Piece.fromChar(char) orelse return InvalidASCII;
                    fen_board.setPieceOn(pce, sq);
                    file += 1;
                },
            }
        }
        rank -= 1;
        file = 0;
    }
    return fen_board;
}

pub fn parseCastleRights(fen: []const u8) !Bitboard {
    var castles = bitboard.empty;
    for (fen) |char| {
        switch (char) {
            '-' => return castles,
            'K' => castles.setBit(Square{ .rank = 0, .file = 7 }),
            'Q' => castles.setBit(Square{ .rank = 0, .file = 0 }),
            'k' => castles.setBit(Square{ .rank = 7, .file = 7 }),
            'q' => castles.setBit(Square{ .rank = 7, .file = 0 }),
            else => return InvalidASCII,
        }
    }
    return castles;
}

pub fn parseNumber(fen: []const u8) !u10 {
    const factors = [4]usize{ 1, 10, 100, 1_000 }; // table in lieu of pow10 function
    var num: usize = 0;
    for (fen) |c, i| {
        if (i > 3) return InvalidASCII;
        num += switch (c) {
            '0'...'9' => (c - '0') * factors[fen.len - 1 - i], // shift to 10's place
            else => return InvalidASCII,
        };
    }
    return @intCast(u10, num);
}

pub fn parseBigNumber(fen: []const u8) !usize {
    var multiplier: usize = 1;
    for (fen) |_| {
        multiplier *= 10;
    }
    var num: usize = 0;
    for (fen) |c, i| {
        multiplier /= 10;
        num += switch (c) {
            '0'...'9' => (c - '0') * multiplier,
            else => return InvalidASCII,
        };
    }
    return num;
}

// An iterator over FENs
pub const Fenerator = struct {
    fen: []const u8, // fen string
    delimiter: u8, // splitting delimiter character
    i: usize = 0, // internal index

    pub fn next(self: *Fenerator) ?[]const u8 {
        while (self.i < self.fen.len and self.isDelimiter(self.fen[self.i])) : (self.i += 1) {}
        if (self.i == self.fen.len) return null;
        const start = self.i;
        while (self.i < self.fen.len and !self.isDelimiter(self.fen[self.i])) : (self.i += 1) {}
        return self.fen[start..self.i];
    }

    fn isDelimiter(self: Fenerator, char: u8) bool {
        return self.delimiter == char;
    }
};
