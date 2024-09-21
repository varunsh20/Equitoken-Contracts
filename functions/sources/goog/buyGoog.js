const ASSET_TICKER = "GOOG"
const SCALING_FACTOR = 10 ** 8;  
const SLEEP_TIME = 5000 // 5 seconds

async function main(){
    const amountTicker = args[0];
    const scaledAmountTicker = (parseFloat(amountTicker) / SCALING_FACTOR).toString();
    const alpacaRequest = Functions.makeHttpRequest({
        url:"https://paper-api.alpaca.markets/v2/account",
        headers:{
            accept:"application/json",
            'APCA-API-KEY-ID':secrets.alpacaKey,
            'APCA-API-SECRET-KEY':secrets.alpacaSecret
        }
    })
    
    const [response] = await Promise.all([alpacaRequest]);
    const portfolioBalance = response.data.portfolio_value;

    let side = "buy"
    let [id, responseStatus] = await placeOrder(ASSET_TICKER, scaledAmountTicker, side)
    if (responseStatus !== 200) {
        return Functions.encodeUint256(0)
    }
    return Functions.encodeUint256(Math.round(portfolioBalance*1000000000000000000));
    
}

async function placeOrder(symbol, qty, side) {
   
    const alpacaSellRequest = Functions.makeHttpRequest({
        method: 'POST',
        url: "https://paper-api.alpaca.markets/v2/orders", 
        headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
            'APCA-API-KEY-ID': secrets.alpacaKey,
            'APCA-API-SECRET-KEY': secrets.alpacaSecret
        },
        data: {
            side: side,
            type: "market",
            time_in_force: "day",
            symbol: symbol,
            qty: qty
        }
    })

    const [response] = await Promise.all([
        alpacaSellRequest,
    ])
    const responseStatus = response.status
    console.log(response)
    const { id, status: orderStatus } = response.data
    return [id, responseStatus]
}

function _checkKeys() {
    if (
        secrets.alpacaKey == "" ||
        secrets.alpacaSecret === ""
    ) {
        throw Error(
            "need alpaca keys"
        )
    }
}

const result = await main();
return result;