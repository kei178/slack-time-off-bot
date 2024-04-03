# Slack Time-off Bot

![Slack Time-off Bot Icon](./slack-time-off-bot.jpg)

This is a Slack bot to to send time-off notifications from the Google PTO calendar.

## How it works

- This bot is triggered to send a time-off notification by Github Actions every morning during weekdays.
- It fetches time-off events from Google Calendar using the Google Console API key.
- It sends today's time-off list to #internal-time-off-notifications on Slack.
