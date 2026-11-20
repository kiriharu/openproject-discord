# OpenProject Discord notifications

[English](README.md) | [Русский](README_RU.md)

OpenProject plugin that posts work package and wiki page changes to Discord
channels. It delivers configurable Discord notifications per project and
channel.

No Discord bot is required: each OpenProject project can define one or more
Discord webhooks and select the events that should be sent to each channel.

## Features

- **Per-project channel mapping.** Every project has its own list of Discord
  channels (webhook URLs). A channel belongs to exactly one project.
- **Selectable events per channel.** Work packages and wiki pages can be
  configured independently.
- **Work package notifications:**
  - created
  - updated (any change)
  - status changed
  - assignee changed
  - comment added
  - deleted
- **Wiki page notifications:**
  - created
  - updated
  - deleted
- **Rich Discord embeds** with the project, work package type, status,
  assignee, priority, author, changed fields and a direct OpenProject link.
- **Test button.** Sends a test message to a channel and reports Discord's
  response.
- **Delivery log.** The last 200 deliveries per channel are kept for
  troubleshooting.
- **Admin overview.** Administrators can see all configured project channels
  and global settings in one place.
- **Safe by design.** Internal notes are excluded by default. Discord mentions
  are disabled in webhook payloads. Failures never break OpenProject save
  operations because delivery happens in a background job.

## Requirements

- OpenProject `>= 16.0.0`
- Ruby `>= 3.4`
- PostgreSQL (OpenProject's standard database)
- Outbound HTTPS access from the `worker` and `web` containers to
  `discord.com`

## Installation

Add the plugin to `Gemfile.plugins` of your OpenProject installation. For
reproducible production builds pin a release tag:

```ruby
group :opf_plugins do
  gem "openproject-discord",
      git: "https://github.com/kiriharu/openproject-discord.git",
      tag: "v0.1.0"
end
```

Install dependencies and run the plugin migrations:

```bash
bundle install
bundle exec rails db:migrate
```

With Docker, run these commands while building your own OpenProject image and
use that image for the `web`, `worker`, `cron` and `seeder` services.

After restarting OpenProject:

1. Open **Administration → Integrations → Discord** and review the global
   settings.
2. Open the target project and enable the **Discord notifications** module in
   **Project settings → Modules**.
3. Open **Project settings → Discord**.
4. Click **Add channel**, paste a Discord webhook URL and select the events.
5. Click **Send test** to verify the connection.

## Creating a Discord webhook

1. Open the required channel in Discord.
2. Choose **Edit channel → Integrations → Webhooks → New Webhook**.
3. Copy the webhook URL. It looks like
   `https://discord.com/api/webhooks/1234567890/abcdef...`.
4. Paste it into the OpenProject channel form.

The webhook URL is effectively a secret: anyone who has it can post to the
channel. It is masked in the list view and is only stored in the OpenProject
database. Use HTTPS and restrict access to project settings accordingly.

## How event selection works

A single OpenProject journal can produce more than one event name. For example,
changing a work package status produces both `work_package:updated` and
`work_package:status_changed`. A channel receives **one** message for that
journal if at least one of the produced event names is selected.

This means:

- selecting **Work package updated** sends every update, including status,
  assignee and comment changes;
- selecting only **Status changed** sends only updates that contain a status
  change;
- selecting **Work package created** does not also send an update message for
  the same creation.

OpenProject aggregates journal notifications for a short, configurable period
before sending them. Discord notifications follow the same aggregation, so they
usually arrive a few minutes after the change rather than instantly.

## Global settings

**Administration → Integrations → Discord** contains:

- master switch for all Discord notifications;
- default webhook display name;
- optional avatar URL;
- whether internal notes may be included in messages (off by default);
- whether a short wiki page excerpt may be included (off by default);
- an overview of every configured project channel.

## Data model

- `discord_channels` — project, friendly name, webhook URL, optional bot name,
  enabled flag and a JSONB array of selected event names.
- `discord_deliveries` — diagnostic log with event names, HTTP status and
  response/error text.

The plugin adds a `discord_channels` association to `Project`.

## Development and tests

Clone the plugin into the `plugins` directory of an OpenProject checkout:

```bash
git clone https://github.com/kiriharu/openproject-discord.git \
  plugins/openproject-discord
```

Use a local path in `Gemfile.plugins`:

```ruby
group :opf_plugins do
  gem "openproject-discord", path: "plugins/openproject-discord"
end
```

Run the plugin specs from the OpenProject root:

```bash
bundle exec rspec plugins/openproject-discord/spec
```

The specs use OpenProject's standard RSpec setup, FactoryBot and WebMock. Set
`OPENPROJECT_ROOT` if the plugin is not inside the OpenProject checkout:

```bash
OPENPROJECT_ROOT=/path/to/openproject \
  bundle exec rspec /path/to/openproject-discord/spec
```

## Troubleshooting

- **Nothing arrives.** Check the master switch, the project module, the channel
  enabled flag and the selected events. Run **Send test**.
- **HTTP 401/404.** The webhook was deleted or the URL is wrong. Create a new
  webhook in Discord.
- **HTTP 429.** Discord rate-limited the webhook. The job retries with
  exponential backoff.
- **Delayed messages.** OpenProject aggregates journal notifications. Lower
  the journal aggregation interval in the administration settings if needed.
- **Worker not running.** Delivery jobs are processed by the OpenProject
  `worker` service.

## License

GNU General Public License v3.0. See [LICENSE](LICENSE).
