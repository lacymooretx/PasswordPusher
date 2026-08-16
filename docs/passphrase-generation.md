# Passphrase & Password Generation

How the "generate a password" button produces its output, and why it is safe to use in front of
colleagues and students.

Last reviewed: 2026-08-16

## Where it happens

Generation is **entirely client-side**. Nothing is sent to the server, and no generated value is
logged. The relevant files:

| File | Role |
| --- | --- |
| `app/javascript/lib/eff_wordlist.js` | The EFF Large Wordlist, 7776 words, unmodified |
| `app/javascript/lib/sfw_wordlist.js` | Denylist + the derived list actually used |
| `app/javascript/controllers/pwgen_controller.js` | Stimulus controller; RNG and assembly |
| `app/views/shared/_pw_generator_modal.html.erb` | The options modal |
| `config/settings.yml` (`gen:` block) | Defaults, all env-overridable |

There are two modes.

### 1. Passphrase mode (default)

Diceware over the EFF Large Wordlist. Words are drawn with `crypto.getRandomValues` — the
browser CSPRNG — using rejection sampling so the draw is exactly uniform:

```js
randomInt(bound) {
    const limit = Math.floor(0x100000000 / bound) * bound
    const array = new Uint32Array(1)
    let value
    do {
        crypto.getRandomValues(array)
        value = array[0]
    } while (value >= limit)
    return value % bound
}
```

The same helper supplies the optional trailing digit, so no part of the output depends on
`Math.random()`.

Shipped defaults: **5 words**, `-` separator, each word capitalised, one trailing digit.

```
Backboard-Obstruct-Stellar-Lurk-Boil1
Cedar-Unbeaten-Spindle-Untried-Badland7
```

### 2. Syllable mode

Pronounceable nonsense via the `omgopass` library — 3 syllables of 1–3 chars drawn from
consonants `bcdfghklmnprstvz` and vowels `aeiouy`, joined with `-_=` (e.g. `ba-tov-zi`). Not
word-based, so the wordlist discussion below does not apply.

> Keep `use_separators: true` for this mode. With separators off, three concatenated random
> syllables can occasionally spell something crude.

## Wordlist provenance

`eff_wordlist.js` is the [EFF Large Wordlist](https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt)
(public domain, 7776 words). It is kept **byte-for-byte unmodified** so provenance stays
verifiable. To re-check it at any time:

```bash
curl -s https://www.eff.org/files/2016/07/18/eff_large_wordlist.txt \
  | awk '{print $2}' | sort > /tmp/eff.txt
# extract the array from eff_wordlist.js, one word per line, sorted, then:
diff /tmp/eff.txt /tmp/repo_words.txt
```

Last run 2026-08-16: **identical, no drift.**

## Is it safe for work and education?

Yes. The EFF list was curated by Joseph Bonneau specifically so it could be read aloud and typed
in front of other people — profanity and slurs were filtered out at design time. A scan of the
7776 words against ~450 crude/sensitive candidates confirmed the genuinely vulgar terms are
absent.

A small number of entries were still awkward for a classroom or a shared screen, so
`sfw_wordlist.js` removes **62 of 7776**, leaving 7714. A word is dropped when it is:

| # | Criterion | Examples removed |
| --- | --- | --- |
| a | Profane or profanity-adjacent | `badass`, `profanity`, `swear` |
| b | Sexual or suggestive | `arousal`, `seduce`, `sensuous`, `massager` |
| c | Reproductive / bodily | `pregnant`, `womb`, `ovary` |
| d | Graphically violent or death-related | `carnage`, `gore`, `casket`, `strangle` |
| e | Weapons | `handgun`, `revolver`, `dagger`, `detonate` |
| f | Charged identity/political terms, or now-slurs | `racism`, `enslave`, `supremacy`, `eskimo` |
| g | Drugs, alcohol, gambling | `cannabis`, `casino`, `opium`, `hangover` |
| h | Religiously loaded | `blasphemy`, `exorcism`, `purgatory`, `ungodly` |

**Ordinary academic vocabulary is deliberately kept**, even where the subject is serious:
`virus`, `epidemic`, `army`, `battle`, `prison`, `theft`, `acid`, `nuclear`, `autopsy`, `dwarf`,
`crazy`. The aim is avoiding embarrassment, not sanitising the dictionary.

### Residual risk

Words are clean individually, but a random multi-word string can still juxtapose into something
that reads suggestively by accident. This is inherent to every diceware scheme and is rare.
Regenerating is one click.

### Changing the policy

Edit `WORDLIST_DENYLIST` in `app/javascript/lib/sfw_wordlist.js`, then `yarn build`. Every entry
must be a word that actually exists in the EFF list — a typo silently removes nothing. The test in
the runlog checks exactly this.

## Entropy

| | Per word | Default | Total |
| --- | --- | --- | --- |
| Unfiltered EFF (7776) | 12.9248 bits | 4 words + digit | 55.0 bits |
| Filtered (7714), current | 12.9133 bits | **5 words + digit** | **67.9 bits** |

The SFW filter costs 0.045 bits across a 4-word passphrase — nothing. The word-count bump from 4
to 5 is what moved the number.

Tune with `PWP__GEN__PASSPHRASE_WORD_COUNT` (modal allows 2–10). Rough guide: 4 words ≈ 51.7 bits,
5 ≈ 64.6, 6 ≈ 77.5, before the optional digit's 3.3 bits.

## Settings reference

All under the `gen:` key in `config/settings.yml`, each with a `PWP__GEN__*` env override.

| Setting | Default | Notes |
| --- | --- | --- |
| `mode` | `passphrase` | or `syllable` |
| `passphrase_word_count` | `5` | modal range 2–10 |
| `passphrase_separator` | `-` | |
| `passphrase_capitalize` | `true` | |
| `passphrase_include_number` | `true` | appends one CSPRNG digit |
| `consonants` / `vowels` | `bcdfghklmnprstvz` / `aeiouy` | syllable mode |
| `use_separators` | `true` | syllable mode — leave on, see above |
| `syllables_count` | `3` | syllable mode |

Per-user overrides are stored in `pwgen_*` cookies and take precedence over these defaults.
