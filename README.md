# TMB Filterer

> WARNING: This is a script, not a fully fleshed out application. It was created
> quickly for a purpose. I'm only putting it on Github to share with the folks that
> this filters data for. If you're not them, it may not make a whole lot of sense.

This was created by [Hound][1] on a whim, and very quicly. If you have comment's or
feedback, leave a Github issue.  It's intended to help Loot Council make informed
decisions, with real numbers.

The idea is that you export the resulting CSV to a Google Sheet.

Some notes about the generation

1. The player, attendance and loot data is pulled directly from [TMB][2]. No calculations are done.
2. If [TMB][2] is not updated, then it will not show the data in this sheet.
3. The script to generate this sheet has to be manually run by Hound and imported. Therefore, if
    Hound is not avilable, there will be no updated.
4. Duplicate items per player are assumed to be accidental and erronious and therefore are removed.
    As such, intentional duplicates may be masked.
5. The prase data is compiled from raw data pulled from the [Warcraftlogs.com V1 API][3]. The numbers
     returned do not match what is shown on the site perfectly. This raw data is calculated using
     the max value from each boss, and then averaged.
6. If "Parse" field is empty,  then no parse data was found. This can happen for various reason, either a bug
    in the generator script, some error on Warcraftlogs.com, or some other undetermined reason.


TODOs (may never get done)
1. Add link on Character name to [TMB][2] page for Character.
2. Add link on Item name to either [TMB][2] item page, or Wowhead item page.
3. Add link on parse number, to actual Character Warcraftlogs.com page.
4. Consider going back father than 30 days.


[1]: https://classic.warcraftlogs.com/character/id/64444943
[2]: https://thatsmybis.com/
[3]: https://www.warcraftlogs.com/v1/docs

## Running
> Note: Assuming understanding of Linux commandline, either via MacOS, Windows WLS,
> or actual Linux.

1. Create a file in this directory called `.env`.
2. Add the following values...
   ```
    TMB_GUILD_GROUP_NAME=<Raid Group Name>
    TMB_OKAY_ALTS=<Comma seperated list of names of Alts to be treated as mains>
    WARCRAFT_LOGS_KEY=<warcraft logs v1 api key>
    WARCRAFT_SERVER=<wow server name>
    WARCRAFT_REGION=<wow server region>
    ```
3. Visit [TMB][2] and go to "Guild > Exports > Giant JSON blob" and click
   "Download JSON" and save it in a file in this directory.
4. Run the script as follows:
   ```
   $ env $(cat .env) ruby ./filter.rb <downloaded json file>
   ```
5. You can then import the generated csv file to Google Sheets.
