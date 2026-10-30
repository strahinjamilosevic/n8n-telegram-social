# n8n Telegram social desk

Post to LinkedIn, Bluesky, and Mastodon from one Telegram message. Read and answer Bluesky and Mastodon replies in Telegram.

This is a template. It holds two n8n workflows, a Docker Compose stack, and every step from an empty account to a working setup. Background and results are in the [case study](https://strahinjamilosevic.com/projects/telegram-social-desk).

## What you get

A private Telegram group with three topics:

| Topic | What happens there |
|---|---|
| Compose | Send a text. The bot shows a preview. Tap **Post to all 3** and it goes to LinkedIn, Bluesky, and Mastodon. |
| Bluesky | New replies, mentions, and quotes, one message each, with a **Like** button. |
| Mastodon | New mentions, one message each, with a **Like** button. |

Reply to a notification in Telegram, tap **Send reply**, and the answer lands under the right post on that platform.

| Workflow | Trigger | Job |
|---|---|---|
| `quick-post` | Every message or button tap to the bot | Previews, posts, replies, likes |
| `engagement` | Every 10 minutes | Forwards new notifications to the topics |
| `error-alert` | Any failure in the other two | Sends the error to your Telegram |

Nothing is stored in a database. Each preview and notification carries its own text and target link.

## Status

Tested on one live setup (n8n 2.43.8): help text, topic IDs, Cancel, second tap refused, a notification run with nothing new, and a real post to all three platforms.

Not tested yet:

- A full reply round trip from another account.
- Importing these cleaned files into a fresh n8n. Personal IDs were removed from the live exports with a script.

## Should you build this?

Probably not, if you only want the result. [Buffer's free plan](https://buffer.com/pricing) lists 3 channels and a community inbox with replies on LinkedIn, Bluesky, and Mastodon. That covers more than this template and needs no server. Other ready-made tools in the same space include Typefully, Publer, Metricool, Later, and Hootsuite.

n8n is not the only way to build it either. Activepieces and Node-RED are also free to self-host, and Make and Zapier are hosted services with no server to run. The steps below are written for n8n, and the workflow files import only into n8n.

Build this if you want to:

- Run everything from Telegram on your phone.
- Keep the workflows and tokens on your own server.
- Learn n8n, Docker, and these APIs.
- Add it to an n8n server you already run. It then costs nothing extra.

## What it cannot do

- LinkedIn comments. Reading them needs `r_member_social`, which LinkedIn does not grant to new apps. Answer them in the LinkedIn app.
- Media. Posts are text and links. Add screenshots by hand on the platform.
- X, Hacker News, Reddit. See [Adding platforms](#adding-platforms).
- Scheduling. A post goes out when you tap the button.

## Costs

Prices checked October 2026, excluding VAT. Check them before you buy.

| Item | Cost per month |
|---|---|
| Hetzner CX23 (2 vCPU, 4 GB RAM) | €5.99 |
| Hetzner backups (20% of the server price) | €1.20 |
| n8n Community Edition, self-hosted | €0 |
| Telegram, Bluesky, Mastodon, LinkedIn APIs | €0 |
| Total | €7.19 |

You also need a domain, because Telegram can only reach n8n at a public HTTPS address. A subdomain of a domain you already own adds nothing.

If you do not own a domain, buy one from a registrar such as [Namecheap](https://www.namecheap.com). Search for a name, add it to the cart, and pay. A `.com` usually costs about €10–15 a year, and other endings vary. To add the record in section 2, open **Domain List** > **Manage** > **Advanced DNS**.

Hetzner showed CX23 as unavailable when checked. If that is still so, take the Regular Performance line (from €6.49) or another location.

Hetzner is only the host. What you need is a Linux virtual private server (VPS) with a public IPv4 address, open ports 22, 80, and 443, Ubuntu, and SSH login as root. This setup has only run on 4 GB of RAM. Other VPS hosts include DigitalOcean, Vultr, Akamai Linode, OVHcloud, and Netcup. Their screens differ from section 1, and the steps from section 2 onward stay the same.

n8n Cloud also works and removes the server steps. Its Starter plan is €20 a month billed annually, with 2,500 executions. Polling every 10 minutes alone uses about 4,320 a month, so poll every 20 minutes or slower on Starter.

## Accounts checklist

Open these before you start. All are free except the server.

- [ ] [GitHub](https://github.com): to fork this repo. Optional if you download the files.
- [ ] [Hetzner Cloud](https://www.hetzner.com/cloud) or another VPS provider. Payment method needed.
- [ ] A domain where you can add DNS records. See [Costs](#costs) if you need to buy one.
- [ ] [Telegram](https://telegram.org) on your phone and desktop.
- [ ] [Bluesky](https://bsky.app) account.
- [ ] [Mastodon](https://joinmastodon.org/servers) account on any instance.
- [ ] [LinkedIn](https://www.linkedin.com) account and a LinkedIn Page you administer. A developer app must be linked to a Page.
- [ ] A password manager for the tokens below.

## Setup

Allow an afternoon. Commands say where they run: **local** is your own terminal, **server** is an SSH session on the VPS.

### 1. Create the server

1. Local: create an SSH key. Accept the default path and set a passphrase.

   ```
   ssh-keygen -t ed25519 -C "n8n-telegram-social"
   ```

2. Local: show the public key and copy it. The file is `~/.ssh/id_ed25519.pub` (on Windows: `$HOME\.ssh\id_ed25519.pub`).
3. Hetzner Console: **Security** > **SSH keys** > add the key.
4. Hetzner Console: **Firewalls** > create one that allows inbound TCP 22, 80, 443 only.
5. Hetzner Console: create a server. Image: Ubuntu 26.04. Type: CX23. SSH key: yours. Enable **Backups**. Attach the firewall.
6. Note the server's IPv4 address.

### 2. Point a hostname at the server

1. In your DNS provider, add an A record. Host: `n8n`. Value: the server's IPv4 address.
2. Local: wait a few minutes, then check it.

   ```
   nslookup n8n.example.com
   ```

   Expected: the server's IPv4 address.

### 3. Secure the server and install Docker

A new server accepts root logins from the whole internet. This section closes that, an action known as hardening, and installs Docker.

1. Local: copy the setup script to the server, from this repo's folder.

   ```
   scp scripts/server-setup.sh root@<server-ip>:/root/
   ```

2. Local: log in.

   ```
   ssh root@<server-ip>
   ```

3. Server: run the script. It asks for a sudo password for the new user `deploy`.

   ```
   bash /root/server-setup.sh
   ```

   Expected: `Done.` The script turns off root login and password login, enables the firewall and security updates, and installs Docker.

4. Keep that session open. Local, in a new window:

   ```
   ssh deploy@<server-ip>
   docker run hello-world
   ```

   Expected: `Hello from Docker!`. You can now close the root session.

### 4. Start n8n

1. Server, as `deploy`: fetch the repo. Use your fork's URL if you made one.

   ```
   git clone https://github.com/strahinjamilosevic/n8n-telegram-social.git
   cd n8n-telegram-social
   cp .env.example .env
   openssl rand -hex 32
   ```

2. Server: edit `.env` with `nano .env`. Set `N8N_HOST` to your hostname, `TIMEZONE` to your timezone, and `N8N_ENCRYPTION_KEY` to the value from `openssl`. Save with Ctrl+O, Enter, Ctrl+X.
3. Save `N8N_ENCRYPTION_KEY` in your password manager. Losing it makes stored credentials unreadable.
4. Server: start the stack.

   ```
   docker compose up -d
   docker compose ps
   ```

   Expected: `caddy` and `n8n` both `running`.

5. Open `https://<your-hostname>` and create the owner account. If the browser shows a certificate error, wait a minute and check `docker compose logs caddy`.
6. Server: add a daily backup. Run `crontab -e` and add this line:

   ```
   0 3 * * * /home/deploy/n8n-telegram-social/scripts/backup.sh >> /home/deploy/backups/backup.log 2>&1
   ```

   Then create the log folder with `mkdir -p /home/deploy/backups`.

### 5. Create the Telegram bot and group

1. Telegram: open @BotFather, send `/newbot`, and follow the prompts. Save the token in your password manager.
2. Telegram: open your new bot's chat and tap **Start**.
3. Telegram: open @userinfobot and note your numeric user ID.
4. Telegram: create a new group with your bot as the only other member.
5. Group settings: turn on **Topics**.
6. Group settings > **Administrators**: add the bot as admin. An admin bot receives every message in the group.
7. Group settings > **Administrators** > yourself: **Remain Anonymous** must be off. Anonymous messages hide your user ID and the bot drops them.
8. Create three topics: `Compose`, `Bluesky`, `Mastodon`.
9. @BotFather: send `/setjoingroups`, pick your bot, choose **Disable**. Nobody can then add it to another group.

### 6. Get the platform tokens

Bluesky:

1. Bluesky > **Settings** > **Privacy and security** > **App passwords** > add one. Name: `n8n`. Do not use your main password: it fails with `AuthFactorTokenRequired`.

Mastodon:

1. Your instance > **Preferences** > **Development** > **New application**.
2. Untick `read`, `write`, `follow`. Tick `read:notifications`, `read:statuses`, `write:statuses`, `write:favourites`. Submit.
3. Open the application and copy **Your access token**.

LinkedIn:

1. https://developer.linkedin.com > **Create app**. Link it to your LinkedIn Page.
2. Tab **Products**: request **Share on LinkedIn** and **Sign In with LinkedIn using OpenID Connect**.
3. Tab **Auth**: copy the Client ID and Client Secret. Leave this tab open for the next section.

### 7. Add the credentials in n8n

Create all four before importing. Use these exact names: the workflows find credentials by name.

In n8n: **Credentials** > **Add credential**.

| Name | Type | Values |
|---|---|---|
| `Telegram quick-post` | Telegram API | Access Token: the bot token |
| `Bluesky app password` | Custom Auth | See below |
| `Mastodon token` | Header Auth | Name: `Authorization`. Value: `Bearer <token>` |
| `LinkedIn` | LinkedIn OAuth2 API | Client ID and Client Secret |

The Custom Auth JSON for Bluesky, with your handle and app password:

```json
{ "body": { "identifier": "you.bsky.social", "password": "xxxx-xxxx-xxxx-xxxx" } }
```

For `LinkedIn`: copy the **OAuth Redirect URL** from the n8n credential into the LinkedIn app's **Auth** tab under **Authorized redirect URLs**. Then click **Connect** in n8n and sign in.

### 8. Import the workflows

There are three workflows. Do them in this order: `quick-post` and `engagement` both report errors to `error-alert`, and `engagement` needs IDs that only `quick-post` can give you.

To import a file: n8n > **Workflows** > **Create workflow** > top-right **...** > **Import from File**.

If your Mastodon instance is not `mastodon.social`, first open `workflows/quick-post.json` and `workflows/engagement.json` in a text editor and replace every `mastodon.social` with your instance's hostname.

#### Workflow 1: `error-alert`

1. Import `workflows/error-alert.json`.
2. **Alert on Telegram**: check the credential is `Telegram quick-post`, and set **Chat ID** to your user ID.
3. Save and click **Publish**.

#### Workflow 2: `quick-post`

1. Import `workflows/quick-post.json`. Expected: 34 nodes.
2. Open each node with a warning and check that its credential is set.
3. **Route**: on the line `const OWNER = 0;`, replace `0` with your user ID.
4. **Post to LinkedIn (link)** and **Post to LinkedIn (text)**: set **Person** to your name from the list.
5. **Send preview**: check **Reply Markup** is Inline Keyboard with `Post to all 3` (Callback Data `post`) and `Cancel` (`cancel`).
6. **Send reply preview**: same, with `Send reply` (`reply`) and `Cancel` (`cancel`). **Parse Mode**: HTML.
7. **Answer: posting**, **Answer: sending**, **Answer button**: **Resource** Callback, **Operation** Answer Query, **Query ID** `{{ $json.query_id }}`.
8. **...** > **Settings**: **Error Workflow** `error-alert`. Save and click **Publish**.

Do not set **Restrict to User IDs** on **On Telegram message**. It drops button taps. **Route** checks the user ID.

#### Workflow 3: `engagement`

1. Telegram: send `/ids` in each of the three topics. Expected: `Chat ID: -100...` and `Topic ID: <number>`.
2. Import `workflows/engagement.json`. Expected: 14 nodes.
3. Open each node with a warning and check that its credential is set.
4. **Config**: fill in `group_chat_id`, `bluesky_topic_id`, `mastodon_topic_id`.
5. **Send to topic**: check **Reply Markup** is Inline Keyboard with `Like` (Callback Data `like`), **Parse Mode** HTML, **Message Thread ID** `{{ $json.topic_id }}`.
6. **...** > **Settings**: **Error Workflow** `error-alert`. Save and click **Publish**.

### 9. Test

Run these in the group, from your phone:

1. Compose: send `/start`. Expected: the help text.
2. Compose: send 320 times the letter a. Expected: `Too long for Bluesky: 320 of 300 characters. Shorten by 20.`
3. Compose: send `Test`, tap **Cancel**. Expected: `Cancelled. Nothing was sent.` Tap **Cancel** again. Expected: `Already handled.`
4. From another account, reply to one of your Bluesky posts. Within 10 minutes, expected: a message in the Bluesky topic.
5. Reply to that message with `Thanks` and tap **Send reply**. Expected: `Replied on Bluesky.` with a link. Open it and check the reply sits under the right post.
6. Repeat steps 4 and 5 on Mastodon. Tap **Like** on one notification.
7. Send a real post in Compose and tap **Post to all 3**. Check the text and link card on each platform.

## Daily use

- New post: send the text in Compose. Limit 300 characters, Bluesky's limit. A link counts as its short form.
- The first https link gets a link card on all three platforms.
- Reply: swipe left on a notification, or long-press and pick **Reply**.
- Each button works once. To fix a typo, tap Cancel and send the corrected text.
- Do not edit or delete notifications. Their link is how a reply finds its target.
- Only your user ID is accepted. Messages from anyone else are dropped without a reply.

## Limits and maintenance

- LinkedIn access tokens expire after 60 days and n8n cannot refresh them. Reconnect: **Credentials** > `LinkedIn` > **Reconnect**.
- Bluesky allows 300 logins a day. `engagement` uses 144 at 10 minutes. Do not poll more often.
- A short outage on Bluesky or Mastodon raises an error alert even though nothing is lost. The next run picks up the notifications. A Bluesky failure also skips that run's Mastodon check.
- Static data (handled buttons, last notification seen) is kept only in published runs. Buttons tapped during a manual test are not remembered.
- Update n8n: read the release notes, change the version in `docker-compose.yml`, then run `docker compose pull` and `docker compose up -d`.
- Restore a backup: stop n8n, extract the archive into the `n8n_data` volume, start n8n. You need the same `N8N_ENCRYPTION_KEY`.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `AuthFactorTokenRequired` from Bluesky | The credential holds your main password | Use an app password |
| Button tap does nothing, no new execution | **Restrict to User IDs** is set | Clear it on **On Telegram message** |
| Bot ignores messages in the group | Bot is not admin, or you post as anonymous | Repeat steps 6 and 7 of section 5 |
| `Fill in Config` error in `engagement` | Topic IDs are missing | Repeat steps 1 and 4 of Workflow 3 in section 8 |
| LinkedIn authorization error | Token expired | Reconnect the credential |

## Adding platforms

| Platform | Posting | Notes |
|---|---|---|
| X | Possible, paid | Pay-per-use API. Third-party sources put a post at about $0.015, and about $0.20 with a link. Check X's own pricing. |
| Hacker News | Manual only | No write API. Read-only comment alerts are possible with the Algolia search API. |
| DEV.to | Possible, free | Takes full articles with a canonical URL, so it suits a blog pipeline more than short posts. |
| Reddit | Needs approval | New API access requires Reddit's approval. |

## Security

- Never commit `.env` or a workflow export with a token in it. Exports hold credential names, not values.
- Keep the n8n host behind HTTPS. Do not publish other ports.
- Revoke a token on its platform if it leaks, then update the n8n credential.

## License

The files in this repo are MIT licensed. n8n itself is under the [Sustainable Use License](https://docs.n8n.io/sustainable-use-license/).

Last updated: October 30, 2026
