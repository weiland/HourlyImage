# 📸 Hourly Image macos App

macOS App which takes photo from the Webcaml, saves it to `~/Pictures/Webcam`
and also tweets it with the current location and Wifi-name.

## Requirements

  * macOS >= 12.0


## Installation

Clone the repo

    $ git clone https://github.com/weiland/HourlyImage
    $ cd HourlyImage

Create a Twitter OAuth App at https://developer.twitter.com/en/apps.

Create a `.twitterCred.json` at `~/Pictures/Webcam/` and fill it with a Twitter OAuth App credentials.

An example file can be found at `./.twitterCred.json.example`. You can move and edit the file: `mv ./.twitterCred.json.example ~/Pictures/Webcam/.twitterCred.json`


Build via XcodeBuild (cli):

    $ xcodebuild archive

Alternatively, the App can be built in Xcode.
The Signing Team might be adjusted.



## Usage

After a successful build the App will be available at `./build/Release/HourlyImage.app`

Run app via (and grant access to _Camera_ and _Location_)

    $ open ./build/Release/HourlyImage.app

You can also install a cronjob which runs on every hour (`crontab -e`) like following:

```sh
0 * * * * open ~/src/github.com/weiland/HourlyImage/build/Release/HourlyImage.app >> /tmp/cron.log 2>&1
```


### Why?

I like to keep track of what I'm doing and where I am. And it's just a habit I'm doing since 


## License

ISC
