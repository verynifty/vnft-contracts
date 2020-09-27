const { Telegraf } = require('telegraf')
const csvdb = require('csv-database');

const bot = new Telegraf("1356132262:AAFM9fpH5foZ16OrC3xIcgILwNRh6XOnWuE")
const BASE_CLAIM_URL = "https://google.com/lol?"
const FILE_TO_SAVE = "claims.csv";
const FILE_TO_READ = "keys.csv";





bot.start(async function (ctx) {
    const proofdb = await csvdb(FILE_TO_READ, ['index', 'leaf', 'proof']);
    const claimeddb = await csvdb(FILE_TO_SAVE, ["telegram_id", "telegram_name", 'index', 'leaf', 'proof']);
    let keys = await proofdb.get()
    console.log(keys)
    console.log(ctx)
    console.log(ctx.chat)
    if (ctx.chat.type == "private") {
        let existing_claim = await claimeddb.get({ telegram_id: ctx.chat.id });
        if (existing_claim.length == 0) {

        } else {

        }
        console.log(existing_claim)
        let claim_index = 3
        let claim_proof = "0x365625643"
        ctx.reply(`Hey ` + ctx.chat.first_name + ` 👋👋`)
        ctx.reply(`I heard you'd love to adopt a cute pet... But remember, this pet is precious so don't let it starve 😋`)
        ctx.reply(`Go there to claim it: ` + BASE_CLAIM_URL + 'ci=' + claim_index + '&cp=' + claim_proof)
        ctx.reply(`You'll need a Ethereum wallet to claim your pet. This link isunique and private for you and ths free pet is only claimable once.`)


    } else {
        ctx.reply(`I'm sorry mate. I only drop pets in 1 on 1 conversations! 🙊 Start messaging me privately.`)
    }

})

bot.launch()