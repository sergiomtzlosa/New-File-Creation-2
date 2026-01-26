#import "NFCStrings.h"
#import "NFErrors.h"
#import "NFVersion.h"

@implementation NFCStrings

+ (NSString *)versionLine {
    return [NSString stringWithFormat:@"nfc %@", NFCVersionString];
}

+ (NSString *)generalHelp {
    return @"nfc — New File Creation 2 command-line utility\n"
           "\n"
           "Usage: nfc <command> [options]\n"
           "\n"
           "Commands:\n"
           "  create [template]     Create a file from a template\n"
           "  list                  List templates\n"
           "  show [template]       Show template details\n"
           "  add <file...>         Add files as templates\n"
           "  remove <template>     Remove a template (moves its file to Trash)\n"
           "  favorite [template]   Toggle or set a template favorite\n"
           "  enable <template>     Enable a template\n"
           "  disable <template>    Disable a template\n"
           "  recent                Show recently used templates\n"
           "  categories            Show template categories and counts\n"
           "  config <action>       path | export | import | reset\n"
           "  status                Show app, config, and Finder status\n"
           "  open [template]       Open a template file or the Templates folder\n"
           "  doctor                Diagnose installation and configuration issues\n"
           "  completion <shell>    Print zsh or bash completion\n"
           "  help [command]        Show help\n"
           "  version               Print the version\n"
           "\n"
           "Global options:\n"
           "  --json                Machine-readable JSON output\n"
           "  --quiet, -q           Minimal output (paths only where applicable)\n"
           "  --plain               Disable decorative formatting\n"
           "  --config <path>       Use a specific config.json\n"
           "  --verbose             Log debug information to stderr\n"
           "  --help, -h            Show help\n"
           "  --version, -v         Show the version\n"
           "\n"
           "Template references are a UUID, display name, file name, or unique\n"
           "prefix. With no reference, the default template is used.\n"
           "\n"
           "Exit codes: 0 ok, 1 error, 2 usage, 3 not found, 4 ambiguous,\n"
           "            5 conflict, 6 config, 7 permission.\n";
}

+ (NSString *)usageForCommand:(NSString *)command {
    NSDictionary<NSString *, NSString *> *usages = @{
        @"create": @"Usage: nfc create [template] [--name <base>] [--output <path>] [--dir <folder>]\n"
                   "                  [--no-unique] [--open] [--reveal] [--sound] [--dry-run]\n",
        @"list": @"Usage: nfc list [--favorites] [--enabled] [--all] [--category <name>]\n",
        @"show": @"Usage: nfc show [template]\n",
        @"add": @"Usage: nfc add <file...> [--name <display name>] [--category <name>]\n"
                "                  [--favorite] [--disabled]\n",
        @"remove": @"Usage: nfc remove <template> [--keep-file] [--yes]\n",
        @"favorite": @"Usage: nfc favorite [template] [--on|--off]\n",
        @"enable": @"Usage: nfc enable <template>\n",
        @"disable": @"Usage: nfc disable <template>\n",
        @"recent": @"Usage: nfc recent [--limit <count>]\n",
        @"categories": @"Usage: nfc categories\n",
        @"config": @"Usage: nfc config <path|export|import|reset> [options]\n"
                   "  config path\n"
                   "  config export [<path>|-]\n"
                   "  config import <path>\n"
                   "  config reset --yes\n",
        @"status": @"Usage: nfc status\n",
        @"open": @"Usage: nfc open [template]\n",
        @"doctor": @"Usage: nfc doctor\n",
        @"completion": @"Usage: nfc completion <zsh|bash>\n",
        @"help": @"Usage: nfc help [command]\n",
        @"version": @"Usage: nfc version\n"
    };
    return usages[command] ?: [NSString stringWithFormat:@"Usage: nfc %@ [options]\n", command];
}

+ (NSString *)helpForCommand:(NSString *)command {
    NSDictionary<NSString *, NSString *> *details = @{
        @"create": @"create — Create a file from a template\n\n"
                   "The default file name comes from the app's defaultBaseName setting\n"
                   "(default: Untitled). --name overrides it. --output sets the full\n"
                   "destination path. Existing files are never overwritten; a unique\n"
                   "suffix is added unless --no-unique is used.\n\n"
                   "  --name, -n <base>     Base name without the template extension\n"
                   "  --output, -o <path>   Full output path (overrides --dir and --name)\n"
                   "  --dir, -d <folder>    Destination folder (default: current directory)\n"
                   "  --no-unique           Fail if the destination exists\n"
                   "  --open                Open the created file\n"
                   "  --reveal              Reveal the created file in Finder\n"
                   "  --sound               Play the completion sound\n"
                   "  --dry-run             Print the destination without creating it\n\n",
        @"list": @"list — List templates\n\n"
                 "  --favorites           Only favorites\n"
                 "  --enabled             Only enabled templates\n"
                 "  --all                 Show all templates, including disabled (default)\n"
                 "  --category <name>     Filter by category\n\n",
        @"show": @"show — Show template details\n\n"
                 "Prints the ID, file name, display name, category, state, path,\n"
                 "creation date, last use, and use count.\n\n",
        @"add": @"add — Add files as templates\n\n"
                "Copies the files into the app's Templates folder. Packages and RTFD\n"
                "bundles are copied recursively. Existing template files are never\n"
                "overwritten; a unique suffix is added when needed.\n\n"
                "  --name <display name>  Human-readable name\n"
                "  --category <name>      Category (default inferred from extension)\n"
                "  --favorite             Mark as favorite\n"
                "  --disabled             Add disabled\n\n",
        @"remove": @"remove — Remove a template\n\n"
                   "Removes the template from the configuration and moves its file to\n"
                   "Trash. Use --keep-file to leave the file in the Templates folder.\n"
                   "  --yes                  Skip the confirmation prompt\n\n",
        @"favorite": @"favorite — Toggle or set a favorite\n\n"
                     "  --on                   Mark as favorite\n"
                     "  --off                  Remove favorite\n\n",
        @"enable": @"enable — Enable a template\n\n",
        @"disable": @"disable — Disable a template\n\n",
        @"recent": @"recent — Show recently used templates\n\n"
                   "  --limit <count>        Number of entries (default 5)\n\n",
        @"categories": @"categories — Show categories and counts\n\n",
        @"config": @"config — Export, import, or reset configuration\n\n"
                   "  config path            Print the config.json path\n"
                   "  config export [path]   Write JSON to a path, or - for stdout\n"
                   "  config import <path>   Replace the configuration from a JSON file\n"
                   "  config reset --yes     Reset to defaults (templates folder is kept)\n\n",
        @"status": @"status — Show configuration, app, CLI, and Finder status\n\n",
        @"open": @"open — Open a template file or the Templates folder\n\n",
        @"doctor": @"doctor — Diagnose common installation and configuration issues\n\n",
        @"completion": @"completion — Print shell completion\n\n"
                       "  zsh                    zsh completion\n"
                       "  bash                   bash completion\n\n"
    };
    NSString *detail = details[command];
    if (!detail) {
        return [self generalHelp];
    }
    return [detail stringByAppendingString:[self usageForCommand:command]];
}

+ (NSString *)errorCodeNameForCode:(NSInteger)code {
    switch (code) {
        case NFErrorTemplateMissing: return @"template_missing";
        case NFErrorTemplateUnreadable: return @"template_unreadable";
        case NFErrorDestinationInvalid: return @"destination_invalid";
        case NFErrorDestinationNotWritable: return @"destination_not_writable";
        case NFErrorNameInvalid: return @"name_invalid";
        case NFErrorFileExists: return @"file_exists";
        case NFErrorConfigCorrupt: return @"config_corrupt";
        case NFErrorConfigWriteFailed: return @"config_write_failed";
        case NFErrorRequestInvalid: return @"request_invalid";
        case NFErrorLockTimeout: return @"lock_timeout";
        case NFErrorMigrationFailed: return @"migration_failed";
        case NFErrorCLIUsage: return @"usage";
        case NFErrorCLINotFound: return @"not_found";
        case NFErrorCLIAmbiguous: return @"ambiguous";
        case NFErrorUnsupportedSchema: return @"unsupported_schema";
        default: return @"error";
    }
}

@end
