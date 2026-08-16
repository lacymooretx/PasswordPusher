// Safe-for-work / safe-for-education filter over the EFF Large Wordlist.
//
// The EFF list is already curated to exclude profanity and slurs, but a handful
// of entries are still awkward to display on a shared screen or read aloud to a
// student. This module keeps EFF_WORDLIST pristine (so its provenance stays
// verifiable against the published file) and derives the list we actually
// generate from.
//
// Removal criteria — a word is dropped when it is:
//   (a) profane or profanity-adjacent
//   (b) sexual or suggestive
//   (c) reproductive/bodily in a way that reads awkwardly out of context
//   (d) graphically violent or death-related
//   (e) a weapon
//   (f) a charged identity/political term, or a term now treated as a slur
//   (g) about drugs, alcohol, or gambling
//   (h) religiously loaded
//
// Ordinary academic vocabulary is deliberately KEPT even when the subject is
// serious: virus, epidemic, army, battle, prison, theft, acid, nuclear, autopsy,
// dwarf, crazy. The goal is avoiding embarrassment, not sanitising the dictionary.
//
// Cost: 62 of 7776 words removed leaves 7714, i.e. 12.913 bits per word instead
// of 12.925 — a loss of 0.045 bits across a 4-word passphrase.

import { EFF_WORDLIST } from "./eff_wordlist"

export const WORDLIST_DENYLIST = new Set([
  // (a) profane / profanity-adjacent
  "badass", "profane", "profanity", "swear", "curse",

  // (b) sexual or suggestive
  "arousal", "lusty", "lustfully", "lustily", "lustiness",
  "seduce", "seducing", "sensually", "sensuous", "unisexual",
  "massager", "groin",

  // (c) reproductive / bodily
  "pregnancy", "pregnant", "womb", "ovary",

  // (d) graphic violence or death
  "carnage", "gore", "gory", "casket", "mortuary", "graveyard",
  "gallows", "strangle", "suffocate", "drown", "undead",

  // (e) weapons
  "handgun", "revolver", "dagger", "detonate", "detonator",

  // (f) charged identity / political terms
  "enslave", "racism", "fascism", "supremacy", "eskimo", "savage",

  // (g) drugs, alcohol, gambling
  "absinthe", "cannabis", "casino", "gambling", "poker", "roulette",
  "wager", "opium", "morphine", "nicotine", "junkie", "hangover",

  // (h) religiously loaded
  "blaspheme", "blasphemy", "exorcism", "exorcist", "purgatory",
  "ungodly", "pagan"
])

// The list passphrases are actually generated from.
export const SFW_WORDLIST = EFF_WORDLIST.filter((word) => !WORDLIST_DENYLIST.has(word))
