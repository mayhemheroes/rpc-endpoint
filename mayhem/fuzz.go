package fuzz

import "strconv"
import "github.com/flashbots/rpc-endpoint/server"

func mayhemit(bytes []byte) int {

    var num int
    if len(bytes) < 1 {
        num = 0
    } else {
        num, _ = strconv.Atoi(string(bytes[0]))
    }

    switch num {
        case 0:
            content := string(bytes)
            _, _ = server.NewRedisState(content)
            return 0

        case 1:
            content := string(bytes)
            var test server.RedisState
            test.GetSenderOfTxHash(content)
            return 0

        default:
            content := string(bytes)
            var test server.RedisState
            test.GetTxSentToRelay(content)
            return 0
    }
}

func Fuzz(data []byte) int {
    _ = mayhemit(data)
    return 0
}