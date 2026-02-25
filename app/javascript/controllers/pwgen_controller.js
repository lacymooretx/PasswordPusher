import { Controller } from "@hotwired/stimulus"
import Cookies from 'js-cookie'
import generatePassword from "omgopass";
import { Modal } from "bootstrap";
import { EFF_WORDLIST } from "../lib/eff_wordlist"

export default class extends Controller {
    static targets = [
        "testPayloadArea",
        "payloadInput",
        "generatePasswordButton",

        "numSyllablesInput",
        "minSyllableLengthInput",
        "maxSyllableLengthInput",
        "includeNumbersCheckbox",
        "useTitleCaseCheckbox",
        "useSeparatorsCheckbox",
        "separatorsInput",
        "vowelsInput",
        "consonantsInput",
        "generateConfirmModal",

        "modePassphraseRadio",
        "modeSyllableRadio",
        "wordCountInput",
        "passphraseSeparatorInput",
        "passphraseCapitalizeCheckbox",
        "passphraseIncludeNumberCheckbox",
        "passphraseOptionsPanel",
        "syllableOptionsPanel"
    ]

    static values = {
        gaEnabled: Boolean,

        useNumbersDefault: Boolean,
        titleCasedDefault: Boolean,
        useSeparatorsDefault: Boolean,
        consonantsDefault: String,
        vowelsDefault: String,
        separatorsDefault: String,
        minSyllableLengthDefault: Number,
        maxSyllableLengthDefault: Number,
        syllablesCountDefault: Number,

        modeDefault: String,
        passphraseWordCountDefault: Number,
        passphraseSeparatorDefault: String,
        passphraseCapitalizeDefault: Boolean,
        passphraseIncludeNumberDefault: Boolean,
    }

    initialize() {
        this.config_defaults = {}
        this.config = {}
        this.isContentGenerated = false
    }

    connect() {
        this.loadSettings()
        this.loadForm()
        this.confirmationModal = new Modal(this.generateConfirmModalTarget)
    }

    setContentNotGenerated() {
        this.isContentGenerated = false
    }

    loadForm() {
        this.numSyllablesInputTarget.value = this.config.syllablesCount
        this.minSyllableLengthInputTarget.value = this.config.minSyllableLength
        this.maxSyllableLengthInputTarget.value = this.config.maxSyllableLength
        this.includeNumbersCheckboxTarget.checked = this.config.hasNumbers
        this.useTitleCaseCheckboxTarget.checked = this.config.titlecased
        this.useSeparatorsCheckboxTarget.checked = this.config.use_separators
        this.separatorsInputTarget.value = this.config.separators
        this.vowelsInputTarget.value = this.config.vowels
        this.consonantsInputTarget.value = this.config.consonants

        // Passphrase fields
        if (this.hasWordCountInputTarget) {
            this.wordCountInputTarget.value = this.config.passphraseWordCount
        }
        if (this.hasPassphraseSeparatorInputTarget) {
            this.passphraseSeparatorInputTarget.value = this.config.passphraseSeparator
        }
        if (this.hasPassphraseCapitalizeCheckboxTarget) {
            this.passphraseCapitalizeCheckboxTarget.checked = this.config.passphraseCapitalize
        }
        if (this.hasPassphraseIncludeNumberCheckboxTarget) {
            this.passphraseIncludeNumberCheckboxTarget.checked = this.config.passphraseIncludeNumber
        }

        // Set mode radio buttons and show/hide panels
        const mode = this.config.mode || 'passphrase'
        if (this.hasModePassphraseRadioTarget) {
            this.modePassphraseRadioTarget.checked = (mode === 'passphrase')
        }
        if (this.hasModeSyllableRadioTarget) {
            this.modeSyllableRadioTarget.checked = (mode === 'syllable')
        }
        this._applyModePanels(mode)
    }

    loadSettings() {
        this.config_defaults = {
            hasNumbers:        this.useNumbersDefaultValue,
            titlecased:        this.titleCasedDefaultValue,
            use_separators:    this.useSeparatorsDefaultValue,
            consonants:        this.consonantsDefaultValue,
            vowels:            this.vowelsDefaultValue,
            separators:        this.separatorsDefaultValue,
            maxSyllableLength: this.maxSyllableLengthDefaultValue,
            minSyllableLength: this.minSyllableLengthDefaultValue,
            syllablesCount:    this.syllablesCountDefaultValue,

            mode:                   this.modeDefaultValue || 'passphrase',
            passphraseWordCount:    this.passphraseWordCountDefaultValue || 4,
            passphraseSeparator:    this.passphraseSeparatorDefaultValue || '-',
            passphraseCapitalize:   this.passphraseCapitalizeDefaultValue,
            passphraseIncludeNumber: this.passphraseIncludeNumberDefaultValue,
        };

        this.config = Object.assign({}, this.config_defaults);

        if (typeof Cookies.get('pwgen_hasNumbers') == 'string') {
            this.config.hasNumbers = this.toBoolean(Cookies.get('pwgen_hasNumbers'))
        }
        if (typeof Cookies.get('pwgen_titlecased') == 'string') {
            this.config.titlecased = this.toBoolean(Cookies.get('pwgen_titlecased'))
        }
        if (typeof Cookies.get('pwgen_use_separators') == 'string') {
            this.config.use_separators = this.toBoolean(Cookies.get('pwgen_use_separators'))
        }
        if (typeof Cookies.get('pwgen_consonants') == 'string') {
            this.config.consonants = Cookies.get('pwgen_consonants')
        }
        if (typeof Cookies.get('pwgen_vowels') == 'string') {
            this.config.vowels = Cookies.get('pwgen_vowels')
        }
        if (typeof Cookies.get('pwgen_separators') == 'string') {
            this.config.separators = Cookies.get('pwgen_separators')
        }
        if (typeof Cookies.get('pwgen_maxSyllableLength') == 'string') {
            this.config.maxSyllableLength = parseInt(Cookies.get('pwgen_maxSyllableLength'))
        }
        if (typeof Cookies.get('pwgen_minSyllableLength') == 'string') {
            this.config.minSyllableLength = parseInt(Cookies.get('pwgen_minSyllableLength'))
        }
        if (typeof Cookies.get('pwgen_syllablesCount') == 'string') {
            this.config.syllablesCount = parseInt(Cookies.get('pwgen_syllablesCount'))
        }

        // Passphrase cookie settings
        if (typeof Cookies.get('pwgen_mode') == 'string') {
            this.config.mode = Cookies.get('pwgen_mode')
        }
        if (typeof Cookies.get('pwgen_passphraseWordCount') == 'string') {
            this.config.passphraseWordCount = parseInt(Cookies.get('pwgen_passphraseWordCount'))
        }
        if (typeof Cookies.get('pwgen_passphraseSeparator') == 'string') {
            this.config.passphraseSeparator = Cookies.get('pwgen_passphraseSeparator')
        }
        if (typeof Cookies.get('pwgen_passphraseCapitalize') == 'string') {
            this.config.passphraseCapitalize = this.toBoolean(Cookies.get('pwgen_passphraseCapitalize'))
        }
        if (typeof Cookies.get('pwgen_passphraseIncludeNumber') == 'string') {
            this.config.passphraseIncludeNumber = this.toBoolean(Cookies.get('pwgen_passphraseIncludeNumber'))
        }
    }

    saveSettings(event) {
        Cookies.set('pwgen_hasNumbers', this.includeNumbersCheckboxTarget.checked)
        Cookies.set('pwgen_titlecased', this.useTitleCaseCheckboxTarget.checked)
        Cookies.set('pwgen_use_separators', this.useSeparatorsCheckboxTarget.checked)
        Cookies.set('pwgen_consonants', this.consonantsInputTarget.value)
        Cookies.set('pwgen_vowels', this.vowelsInputTarget.value)
        Cookies.set('pwgen_separators', this.separatorsInputTarget.value)
        Cookies.set('pwgen_maxSyllableLength', this.maxSyllableLengthInputTarget.value)
        Cookies.set('pwgen_minSyllableLength', this.minSyllableLengthInputTarget.value)
        Cookies.set('pwgen_syllablesCount', this.numSyllablesInputTarget.value)

        // Save passphrase settings
        const mode = this.hasModePassphraseRadioTarget && this.modePassphraseRadioTarget.checked ? 'passphrase' : 'syllable'
        Cookies.set('pwgen_mode', mode)
        if (this.hasWordCountInputTarget) {
            Cookies.set('pwgen_passphraseWordCount', this.wordCountInputTarget.value)
        }
        if (this.hasPassphraseSeparatorInputTarget) {
            Cookies.set('pwgen_passphraseSeparator', this.passphraseSeparatorInputTarget.value)
        }
        if (this.hasPassphraseCapitalizeCheckboxTarget) {
            Cookies.set('pwgen_passphraseCapitalize', this.passphraseCapitalizeCheckboxTarget.checked)
        }
        if (this.hasPassphraseIncludeNumberCheckboxTarget) {
            Cookies.set('pwgen_passphraseIncludeNumber', this.passphraseIncludeNumberCheckboxTarget.checked)
        }

        this.config = {
            hasNumbers: this.includeNumbersCheckboxTarget.checked,
            titlecased: this.useTitleCaseCheckboxTarget.checked,
            use_separators: this.useSeparatorsCheckboxTarget.checked,
            consonants: this.consonantsInputTarget.value,
            vowels: this.vowelsInputTarget.value,
            separators: this.separatorsInputTarget.value,
            maxSyllableLength: Number(this.maxSyllableLengthInputTarget.value),
            minSyllableLength: Number(this.minSyllableLengthInputTarget.value),
            syllablesCount: Number(this.numSyllablesInputTarget.value),

            mode: mode,
            passphraseWordCount:     this.hasWordCountInputTarget ? Number(this.wordCountInputTarget.value) : this.config.passphraseWordCount,
            passphraseSeparator:     this.hasPassphraseSeparatorInputTarget ? this.passphraseSeparatorInputTarget.value : this.config.passphraseSeparator,
            passphraseCapitalize:    this.hasPassphraseCapitalizeCheckboxTarget ? this.passphraseCapitalizeCheckboxTarget.checked : this.config.passphraseCapitalize,
            passphraseIncludeNumber: this.hasPassphraseIncludeNumberCheckboxTarget ? this.passphraseIncludeNumberCheckboxTarget.checked : this.config.passphraseIncludeNumber,
        }
    }

    resetSettings(event) {
        this.config = Object.assign({}, this.config_defaults);
        this.loadForm()
    }

    switchMode(event) {
        const mode = event.currentTarget.value
        this.config.mode = mode
        this._applyModePanels(mode)
    }

    _applyModePanels(mode) {
        if (this.hasPassphraseOptionsPanelTarget && this.hasSyllableOptionsPanelTarget) {
            if (mode === 'passphrase') {
                this.passphraseOptionsPanelTarget.classList.remove('d-none')
                this.syllableOptionsPanelTarget.classList.add('d-none')
            } else {
                this.passphraseOptionsPanelTarget.classList.add('d-none')
                this.syllableOptionsPanelTarget.classList.remove('d-none')
            }
        }
    }

    configureGenerator(event) {
        if (this.gaEnabledValue == true) {
            gtag('event', 'configure_pw_generator',
                    { 'event_category' : 'engagement',
                    'event_label' : 'Configure Password Generator Dialog' });
        }
    }

    generatePassphrase(cfg) {
        const config = cfg || this.config
        const count = config.passphraseWordCount || 4
        const words = []
        const array = new Uint32Array(count)
        crypto.getRandomValues(array)
        for (const val of array) {
            let word = EFF_WORDLIST[val % EFF_WORDLIST.length]
            if (config.passphraseCapitalize) {
                word = word.charAt(0).toUpperCase() + word.slice(1)
            }
            words.push(word)
        }
        let result = words.join(config.passphraseSeparator !== undefined ? config.passphraseSeparator : '-')
        if (config.passphraseIncludeNumber) {
            result += Math.floor(Math.random() * 10)
        }
        return result
    }

    testGenerate(event) {
        const isPassphrase = this.hasModePassphraseRadioTarget && this.modePassphraseRadioTarget.checked

        if (isPassphrase) {
            const testConfig = {
                mode: 'passphrase',
                passphraseWordCount:     this.hasWordCountInputTarget ? Number(this.wordCountInputTarget.value) : (this.config.passphraseWordCount || 4),
                passphraseSeparator:     this.hasPassphraseSeparatorInputTarget ? this.passphraseSeparatorInputTarget.value : (this.config.passphraseSeparator || '-'),
                passphraseCapitalize:    this.hasPassphraseCapitalizeCheckboxTarget ? this.passphraseCapitalizeCheckboxTarget.checked : this.config.passphraseCapitalize,
                passphraseIncludeNumber: this.hasPassphraseIncludeNumberCheckboxTarget ? this.passphraseIncludeNumberCheckboxTarget.checked : this.config.passphraseIncludeNumber,
            }
            this.testPayloadAreaTarget.innerText = this.generatePassphrase(testConfig)
        } else {
            let testConfig = {
                hasNumbers: this.includeNumbersCheckboxTarget.checked,
                titlecased: this.useTitleCaseCheckboxTarget.checked,
                use_separators: this.useSeparatorsCheckboxTarget.checked,
                consonants: this.consonantsInputTarget.value,
                vowels: this.vowelsInputTarget.value,
                separators: this.separatorsInputTarget.value,
                maxSyllableLength: Number(this.maxSyllableLengthInputTarget.value),
                minSyllableLength: Number(this.minSyllableLengthInputTarget.value),
                syllablesCount: Number(this.numSyllablesInputTarget.value)
            }
            if (testConfig.use_separators === false) {
                testConfig.separators = ''
            }
            this.testPayloadAreaTarget.innerText = generatePassword(testConfig)
        }
    }

    producePassword() {
        const existingContent = this.payloadInputTarget.value.trim();

        // If there's existing content that was NOT generated by this controller, show confirmation modal
        if (existingContent.length > 0 && !this.isContentGenerated) {
            this.confirmationModal.show();
            return;
        }

        this.generatePassword();
    }

    generateConfirm() {
        this.confirmationModal.hide();
        this.generatePassword();
    }

    generatePassword() {
        const mode = this.config.mode || 'passphrase'

        if (mode === 'passphrase') {
            this.payloadInputTarget.value = this.generatePassphrase()
        } else {
            if (this.config.use_separators === false) {
                this.config.separators = ''
            }
            this.payloadInputTarget.value = generatePassword(this.config)
        }

        // Mark content as generated by this controller
        this.isContentGenerated = true

        if (this.gaEnabledValue) {
            gtag('event', 'generate_password',
                    { 'event_category' : 'engagement',
                    'event_label' : 'Generate a Password' });
        }
    }

    toBoolean(candidate) {
        if (candidate) {
            if (typeof candidate === 'string') {
                return candidate == 'true';
            } else if (typeof candidate === 'boolean') {
                return candidate;
            }
        }
        return null;
    }
}
