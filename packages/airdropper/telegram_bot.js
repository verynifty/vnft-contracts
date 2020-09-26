const { Telegraf } = require('telegraf')

const bot = new Telegraf("1356132262:AAFM9fpH5foZ16OrC3xIcgILwNRh6XOnWuE")
const BASE_CLAIM_URL = "https://google.com/lol?"

bot.start(function (ctx) {
    console.log(ctx)
    console.log(ctx.chat)
    if (ctx.chat.type == "private") {
        let claim_index = 3
        let claim_proof = "0x365625643"
        ctx.reply(`Hey ` + ctx.chat.first_name + ` 👋👋`)
        ctx.reply(`I heard you'd love to adopt a cute pet... But remember, this pet is precious so don't let it starve 😋`)
        ctx.reply(`Go there to claim it: ` + BASE_CLAIM_URL + 'ci=' + claim_index + '&cp=' + claim_proof)
        ctx.reply(`You'll need a Ethereum wallet to claim your pet. This link is unique and private for you and ths free pet is only claimable once.`)


    } else {
        ctx.reply(`I'm sorry mate. I only drop pets in 1 on 1 conversations! 🙊 Start messaging me privately.`)
    }

})

bot.launch()