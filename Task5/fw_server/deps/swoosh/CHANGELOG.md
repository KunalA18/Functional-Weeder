## Changelog

## 1.5.2

### Fixes

- Fix closing tag @feld (#634)

## 1.5.1

### ✨ Features

- Adding support for inline attachments preview in MailboxPreview @theodowling (#628)

### 📝 Documentation

- Fixing Typo @Orijhins (#629)
- Further cleanup async section @josevalim (#621)
- Build upon async emails section @josevalim (#620)
- Fix typos @kianmeng (#618)
- Fix a few typos in the docs @nickjj (#617)

## 1.5.0

### ✨ Features

- Add telemetry to `Mailer.deliver` \& `Mailer.deliver_many` @joshnuss (#614)

### 📝 Documentation

- Improve README.md - mention `api_client` as false @philss (#610)

## 1.4.0

### Add `Swoosh.ApiClient.Finch`

You can configure what API Client to use by setting the config. Swoosh comes with
`Swoosh.ApiClient.Hackney` and `Swoosh.ApiClient.Finch`

```elixir
config :swoosh, :api_client, MyAPIClient
```

It defaults to use `:hackney` with `Swoosh.ApiClient.Hackney`. To use `Finch`, add the below config

```elixir
config :swoosh, :api_client, Swoosh.ApiClient.Finch
```

To use `Swoosh.ApiClient.Finch` you also need to start `Finch`, either in your supervision tree

```elixir
children = [
  {Finch, name: Swoosh.Finch}
]
```

or somehow manually, and very rarely dynamically

```elixir
Finch.start_link(name: Swoosh.Finch)
```

If a name different from `Swoosh.Finch` is used, or you want to use an existing Finch instance,
you can provide the name via the config.

```elixir
config :swoosh,
  api_client: Swoosh.ApiClient.Finch,
  finch_name: My.Custom.Name
```

[Pre-1.4 changelogs](https://github.com/swoosh/swoosh/blob/v1.3.11/CHANGELOG.md)
