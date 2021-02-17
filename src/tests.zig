const testing = @import("std").testing;
const std = @import("std");
const expectEqual = testing.expectEqual;
const expect = testing.expect;
const print = @import("std").debug.print;


const attack = @import("attack.zig");
const bitboard = @import("bitboard.zig");
const board = @import("board.zig");
const calculate = @import("calculate.zig");
const color = @import("color.zig");
const errors = @import("errors.zig");
const fen = @import("fen.zig");
const magic = @import("magic.zig");
const move = @import("move.zig");
const piece = @import("piece.zig");
const position = @import("position.zig");
const setup = @import("setup.zig");
const square = @import("square.zig");

pub var nodes: usize = 0;

pub fn perft(pos: position.Position, depth: usize) errors.ChessError![3]usize {
    nodes += 1;
    if (depth < 1) return [3]usize{0, 0, 0};
    var moves = try calculate.legalMoves(pos);
    if (depth == 1) {
        return [3]usize{moves.len, 0, 0};
    } else {
        // var sum: usize = 0;
        var results: [3]usize = [3]usize{0, 0, 0};
        while (moves.next()) |m| {
            var child = pos.clone();
            child.playMove(m);
            results[1] += if (m.isCapture()) @as(usize, 1) else @as(usize, 0);
            results[2] += if (child.isCheck()) @as(usize, 1) else @as(usize, 0);
            const other_results = try perft(child, depth - 1);
            results[0] += other_results[0];
            results[1] += other_results[1];
            results[2] += other_results[2];
        }
        return results;
    }
}

test "new and count" {
    expect(bitboard.new(0x003C0000038F6AAA).count() == 19);
}

test "legal chess position" {
    const brd = position.standard().board;
    expect(board.isLegal(brd));
}

test "standard board standard position string representation" {
    // I can't figure out how to compare the damn string types I've tried bitcasting, setting the
    // string I output on the debug to terminal - 0; taking slices, trying to convert from a pointer,
    // using expect(x == y) as well as expectEqual(x == y) --- I need "comparing zig strings for
    // dummies" as a document to read.
    // I had originally done this with multiline strings... but copy-pasting the chessboard
    // into here somehow made it like 83 characters rather than 72, but then going back to 'main'
    // and checking it, it was 72 characters. So I have NO CLUE wtf is happening.
    const string = try position.standard().board.debug();
    const start = "rnbqkbnr\npppppppp\n........\n........\n........\n........\nPPPPPPPP\nRNBQKBNR\n";
    var i: usize = 0;
    while (i < 72) : (i += 1) {
        expect(start[i] == string[i]);
    }
}

test "starting legal moves" {
    setup.init();
    var moves = try calculate.legalMoves(position.standard());
    expect(moves.len == 20);
}

test "legal board" {
    const empty = board.empty();
    const standard = board.standard();
    expect(board.isLegal(empty));
    expect(board.isLegal(standard));
}

test "fen parse and simple legals" {
    setup.init();
    const fen_str = "rnbqkbnr/pp2P1pp/8/1Ppp4/5pP1/8/P1P1PP1P/RNBQKBNR w KQkq c6 0 1";
    var parsed = try fen.ascii(fen_str);
    var moves = try calculate.legalMoves(parsed);
    expect(moves.len == 37);
}

test "perft" {
    setup.init();
    var pos = position.standard();
    expect((try perft(pos, 0)) == @as(usize, 1));
    expect((try perft(pos, 1)) == @as(usize, 20));
    expect((try perft(pos, 2)) == @as(usize, 400));
    expect((try perft(pos, 3)) == @as(usize, 8_902));
    expect((try perft(pos, 4)) == @as(usize, 197_281));
    expect((try perft(pos, 5)) == @as(usize, 4_865_609));
    expect((try perft(pos, 6)) == @as(usize, 119_060_324));
    expect((try perft(pos, 7)) == @as(usize, 3_195_901_860));
    // 6    119_060_324	
    // 7    3_195_901_860	
    // 8    84_998_978_956	
    // 9    2_439_530_234_167	
    // 10    69_352_859_712_417
    // 11    2_097_651_003_696_806
    // 12    62_854_969_236_701_747
    // 13    1_981_066_775_000_396_239
    // 14    61_885_021_521_585_529_237
    // 15    2_015_099_950_053_364_471_960
    // chessprogramming.org/Perft_Results
}
