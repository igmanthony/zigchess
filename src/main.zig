const std = @import("std");
const print = @import("std").debug.print;
const assert = std.debug.assert;
const time = std.time;


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
const perft = @import("perft.zig");
const setup = @import("setup.zig");
const square = @import("square.zig");
const tests = @import("tests.zig");



pub fn main() !void {
    setup.init();

    // for (perft.perfts) |p, index| {
    //     print("\nindex: {}; {s}\n", .{ index, p.fen });
    //     const pos = try fen.ascii(p.fen);
    //     var answers = fen.Fenerator{ .fen = p.numbers, .delimiter = ',' };
    //     const first_answer = try fen.parseBigNumber(answers.next().?);
    //     const second_answer = try fen.parseBigNumber(answers.next().?);
    //     const my_result = try tests.perft(pos, 1);
    //     if (my_result != first_answer) {
    //         print("\n\nFIRST INCORRECT!:\nTheir answer: {}\n My answer: {}\n FEN: {s}\n Numbers: {s}\n", .{ second_answer, my_result, p.fen, p.numbers });
    //         var moves = try calculate.legalMoves(pos);
    //         while (moves.next()) |m| {
    //             print("{s}\n", .{m.toString()});
    //         }
    //         print("\n{s}\n", .{try pos.board.debug()});
    //         print("----------------", .{});
    //         assert(false);
    //     }
    //     assert(my_result == first_answer);
    // }

    var pos = position.standard();
    var i: usize = 0;
    var timer = try time.Timer.start();
    while (i < 9) : (i += 1) {
        tests.nodes = 0;
        const results = try tests.perft(pos, i);
        const result = results[0];
        const checks = results[1];
        const captures = results[2];
        const stdout = std.io.getStdOut().writer();
        const new_time = timer.lap();
        try stdout.print("Result, {} at depth {} and time: {}, nodes per s: {}, captures: {}, checks: {}!\n", 
        .{result, i, new_time, (@intToFloat(f64, tests.nodes) / (@intToFloat(f64, new_time) / 1e9)), captures, checks} );
    }


}


// Result, 1 at depth 0 and time: 500, nodes per s: 2.0e+06!
// Result, 20 at depth 1 and time: 873600, nodes per s: 1.1446886446886447e+03!
// Result, 400 at depth 2 and time: 389000, nodes per s: 5.3984575835475574e+04!
// Result, 8902 at depth 3 and time: 360100, nodes per s: 1.1691196889752846e+06!
// Result, 197281 at depth 4 and time: 3546100, nodes per s: 2.629085474182905e+06!
// Result, 4865609 at depth 5 and time: 73863100, nodes per s: 2.797120619091265e+06!
// Result, 119060324 at depth 6 and time: 1696368500, nodes per s: 2.9900419631701484e+06!
// Result, 3195901860 at depth 7 and time: 44217069500, nodes per s: 2.807344276852178e+06!