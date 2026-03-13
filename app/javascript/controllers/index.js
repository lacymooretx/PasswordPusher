import ClipboardController from "./clipboard_controller"
import CopyController from "./copy_controller"
import CountdownController from "./countdown_controller"
import EncryptedDownloadController from "./encrypted_download_controller"
import EncryptedUploadController from "./encrypted_upload_controller"
import FormController from "./form_controller"
import GdprController from "./gdpr_controller"
import KnobsController from "./knobs_controller"
import MultiUploadController from "./multi_upload_controller"
import PWGenController from "./pwgen_controller"
import PasswordsController from "./passwords_controller"
import TemplateSelectController from "./template_select_controller"
import ThemeController from "./theme_controller"
import { application } from "./application"

application.register("clipboard", ClipboardController)
application.register("encrypted-download", EncryptedDownloadController)
application.register("encrypted-upload", EncryptedUploadController)
application.register("gdpr", GdprController)
application.register("copy", CopyController)
application.register("countdown", CountdownController)
application.register("pwgen", PWGenController)
application.register("form", FormController)
application.register("knobs", KnobsController)
application.register("passwords", PasswordsController)
application.register("multi-upload", MultiUploadController)
application.register("template-select", TemplateSelectController)
application.register("theme", ThemeController)
