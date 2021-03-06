import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:console/console.dart';
import 'package:dappstarter_cli/commands/upgrade.dart';
import 'package:dappstarter_cli/models/manifest.dart';
import 'package:dappstarter_cli/services/DappStarterService.dart';
import 'package:dappstarter_cli/services/ConfigService.dart';
import 'package:path/path.dart';

void main(List<String> args) {
  var runner = CommandRunner('dappstarter', 'Full-Stack Blockchain App Mojo');
  runner..addCommand(DappStarterCommand());
  runner..addCommand(UpgradeCommand());
  runner.run(args);
}

class DappStarterCommand extends Command {
  @override
  String get description => 'Create dappstarter project';
  @override
  String get name => 'create';
  @override
  String get usageFooter => 'Example: dappstarter create -c config.json';

  DappStarterCommand() {
    argParser.addOption('output',
        abbr: 'o',
        help: 'Output directory. If omitted current directory will be used.');
    argParser.addOption('config',
        abbr: 'c', help: 'Loads configuration from file and processes.');
    argParser.addOption('config-only',
        abbr: 'w', help: 'Writes configuration to file without processing.');
  }

  var options = <String, dynamic>{};

  String dappName = basename(Directory.current.path);

  @override
  void run() async {
    if (argResults['config'] != null) {
      var data = await ConfigService.getLocalFile(argResults['config']);
      if (data == null) {
        return;
      }

      var prompt = '${Icon.STAR} Configuration loaded. Generating project...';
      TextPen()
        ..green()
        ..text(prompt).print();
      Console.moveCursorUp();
      Console.moveCursorForward(prompt.length + 1);
      var timer = TimeDisplay();
      timer.start();

      dappName = data.name;
      options = data.blocks;

      await DappStarterService.postSelections(
          argResults['output'], dappName, options);
      timer.stop();
      return;
    }

    var manifestList = await DappStarterService.getManifest();
    if (manifestList != null) {
      var question = 'Enter name for your dapp ($dappName)';
      TextPen()
        ..yellow()
        ..text(question).print();
      var result = stdin.readLineSync();
      if (result == null) {
        exit(0);
      }
      Console.moveCursorUp(2);
      Console.eraseDisplay();
      if (result != '') {
        dappName = result;
      }
      TextPen()
        ..darkBlue()
        ..text('${Icon.HEAVY_CHECKMARK} Enter name for your dapp: $dappName')
            .print();
      for (var manifest in manifestList) {
        showMultiplePicker(manifest);
      }

      if (argResults['config-only'] != null) {
        TextPen()
          ..green()
          ..text('${Icon.STAR} DappStarter complete. Saving configuration file.')
              .print();
        await ConfigService.writeConfig(
            argResults['config-only'], dappName, options);
      } else {
        var prompt = '${Icon.STAR} DappStarter complete. Generating project...';
        TextPen()
          ..green()
          ..text(prompt).print();
        Console.moveCursorUp();
        Console.moveCursorForward(prompt.length + 1);
        var timer = TimeDisplay();
        timer.start();
        await DappStarterService.postSelections(
            argResults['output'], dappName, options);
        timer.stop();
      }
    }
  }

  void showMultiplePicker(Manifest manifest) {
    var menuList = manifest.children
        .where((x) => x.interface.enabled)
        .map((x) => x.title)
        .toList();
    for (var i = 0; i < menuList.length; i++) {
      print('${(i + 1).toString().padLeft(3)}) ${menuList[i]}');
    }
    var question = 'Select ${manifest.singular ?? manifest.name}';
    var exitCodeMsg = '';
    if (manifest.name == 'categories') {
      exitCodeMsg = ' (0 to continue)';
    }
    TextPen()
      ..yellow()
      ..text(question + exitCodeMsg).print();
    var result = stdin.readLineSync();
    if (result == null) {
      exit(0);
    }
    Console.moveCursorUp(menuList.length + 2);
    Console.eraseDisplay();

    var intValue = int.tryParse(result) ?? 0;
    intValue--;

    if (intValue == -1) {
      return;
    }

    var resultName = menuList[intValue];
    TextPen()
      ..darkBlue()
      ..text('${Icon.HEAVY_CHECKMARK} $question: $resultName').print();

    var selection = manifest.children[intValue].name;
    var path = '/${manifest.name}/$selection';

    options.putIfAbsent(path, () => true);

    if (manifest.children[0].children?.length == null) {
      return;
    }

    showOption(path, manifest.children[intValue]);
    showMultiplePicker(manifest);
  }

  void showOption(String path, Manifest manifest) {
    var menuList = manifest.children
        .where((x) => x.interface.enabled)
        .map((x) => x.title)
        .toList();
    for (var i = 0; i < menuList.length; i++) {
      print('${(i + 1).toString().padLeft(3)}) ${menuList[i]}');
    }

    TextPen()
      ..yellow()
      ..text('Select option (Enter or 0 to exit)').print();
    var result = stdin.readLineSync();
    if (result == null) {
      exit(0);
    }
    var intValue = int.tryParse(result) ?? 0;
    intValue--;
    if (intValue == -1 ||
        (manifest.children[0].children?.length == null &&
            manifest.children[0].parameters == null)) {
      return;
    }
    Console.moveCursorUp(menuList.length + 2);
    Console.eraseDisplay();
    TextPen()
      ..darkBlue()
      ..text('${Icon.HEAVY_CHECKMARK} Select option: ' +
              manifest.children[intValue].title)
          .print();

    var optionPath = path + '/' + manifest.children[intValue].name;

    options.putIfAbsent(optionPath, () => true);

    if (manifest?.children[intValue]?.parameters != null &&
        manifest.children[intValue].parameters.isNotEmpty) {
      showParams(optionPath, manifest.children[intValue].parameters);
    }
  }

  void showParams(String path, List<Parameters> parameters) {
    for (var i = 0; i < parameters.length; i++) {
      final param = parameters[i];
      if (param.type == 'choice') {
        var menuList = param.options.map((x) => x.title).toList();
        for (var i = 0; i < menuList.length; i++) {
          print('${(i + 1).toString().padLeft(3)}) ${menuList[i]}');
        }

        var question = 'Select ${param.title}';
        TextPen()
          ..yellow()
          ..text(question).print();
        var result = stdin.readLineSync();
        if (result == null) {
          exit(0);
        }
        var intValue = int.tryParse(result) ?? 0;
        if (intValue == -1) {
          return;
        }
        Console.moveCursorUp(menuList.length + 2);
        Console.eraseDisplay();
        TextPen()
          ..darkBlue()
          ..text('${Icon.HEAVY_CHECKMARK} $question: ${param.options[intValue].title}')
              .print();
        options.putIfAbsent(
            path + '/' + param.name + '/' + param.options[intValue].name,
            () => true);
      } else {
        var placeHolder =
            param.placeholder != null ? (param.placeholder + ', ') : '';
        TextPen()
          ..yellow()
          ..text('Enter: ${param.title} ($placeHolder${param.description})')
              .print();
        var result = stdin.readLineSync();
        if (result == null) {
          exit(0);
        }
        Console.moveCursorUp(2);
        Console.eraseDisplay();
        var intValue = int.tryParse(result) ?? 0;
        if (intValue == -1) {
          return;
        }
        TextPen()
          ..darkBlue()
          ..text('Enter: ${param.title}: $result');
        options.putIfAbsent(path + '/' + param.name, () => result);
      }
    }
  }
}
