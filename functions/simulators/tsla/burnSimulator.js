const requestConfig = require("../../configs/tsla/burnConfig.js")
const { simulateScript, decodeResult } = require("@chainlink/functions-toolkit")


async function main() {
    console.log(requestConfig);
    const { responseBytesHexstring, errorString, capturedTerminalOutput } = await simulateScript(requestConfig)
    console.log(`${capturedTerminalOutput}\n`)
    if (responseBytesHexstring) {
        console.log(
            `Response returned by script during local simulation: ${decodeResult(
                responseBytesHexstring,
                requestConfig.expectedReturnType
            ).toString()}\n`
        )
    }
    if (errorString) {
        console.log(`Error returned by simulated script:\n${errorString}\n`)
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});