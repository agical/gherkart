// Copyright (c) 2024-2026 Agical AB. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import 'package:gherkart/gherkart.dart';
import 'package:test/test.dart';

void main() {
  group('Multi-language support (i18n)', () {
    test('supports French (# language: fr)', () {
      const content = '''
# language: fr
Fonctionnalité: Calculatrice
  Contexte:
    Soit la calculatrice prête

  Scénario: Addition simple
    Soit le nombre 1
    Quand j'ajoute 2
    Alors le résultat est 3
    Et que le voyant est vert
    Mais que l'alarme est éteinte
    * une étape libre

  Plan du scénario: Additions multiples
    Quand j'additionne <a> et <b>
    Alors j'obtiens <total>

    Exemples:
      | a | b | total |
      | 5 | 5 | 10    |
''';
      final feature = parseFeature(content, 'test_fr.feature');

      expect(feature.name, 'Calculatrice');
      expect(feature.background?.steps.first.keyword, StepKeyword.given);
      expect(feature.background?.steps.first.text, 'la calculatrice prête');
      expect(feature.background?.steps.first.fullText, 'Soit la calculatrice prête');

      // Scenario steps
      final sc = feature.scenarios[0];
      expect(sc.name, 'Addition simple');
      expect(sc.steps[0].keyword, StepKeyword.given);
      expect(sc.steps[0].fullText, 'Soit le nombre 1');
      expect(sc.steps[1].keyword, StepKeyword.when);
      expect(sc.steps[1].fullText, "Quand j'ajoute 2");
      expect(sc.steps[2].keyword, StepKeyword.then);
      expect(sc.steps[2].fullText, 'Alors le résultat est 3');
      expect(sc.steps[3].keyword, StepKeyword.and);
      expect(sc.steps[3].fullText, 'Et que le voyant est vert');
      expect(sc.steps[4].keyword, StepKeyword.and);
      expect(sc.steps[4].fullText, "Mais que l'alarme est éteinte");
      expect(sc.steps[5].keyword, StepKeyword.star);
      expect(sc.steps[5].fullText, '* une étape libre');

      // Outline expansion in French
      expect(feature.scenarioOutlines, hasLength(1));
      final outline = feature.scenarioOutlines[0];
      expect(outline.name, 'Additions multiples');
      final expanded = outline.expandToScenarios();
      expect(expanded, hasLength(1));
      expect(expanded[0].steps[0].text, "j'additionne 5 et 5");
      expect(expanded[0].steps[1].text, "j'obtiens 10");
    });

    test('supports German (# language: de)', () {
      const content = '''
# language: de
Funktionalität: Benutzerverwaltung
  Grundlage:
    Angenommen die Datenbank ist online

  Regel: Nur Administratoren dürfen Benutzer bearbeiten
    Grundlage:
      Angenommen ich bin als Administrator eingeloggt

    Szenario: Benutzer löschen
      Wenn ich den Benutzer "Alice" lösche
      Dann ist "Alice" nicht mehr vorhanden
      Und eine Erfolgsmeldung wird angezeigt
      Aber keine Fehlermeldung erscheint

    Szenariogrundriss: Benutzer anlegen mit Rolle
      Wenn ich einen Benutzer mit Rolle <rolle> anlege
      Dann hat der Benutzer die Rolle <rolle>

      Beispiele:
        | rolle  |
        | editor |
        | viewer |
''';
      final feature = parseFeature(content, 'test_de.feature');

      expect(feature.name, 'Benutzerverwaltung');
      expect(feature.background?.steps[0].keyword, StepKeyword.given);
      expect(feature.background?.steps[0].fullText, 'Angenommen die Datenbank ist online');

      // Scenario under Rule in German
      expect(feature.scenarios, hasLength(1));
      final sc = feature.scenarios[0];
      expect(sc.name, 'Benutzer löschen');
      expect(sc.steps, hasLength(5));
      expect(sc.steps[0].text, 'ich bin als Administrator eingeloggt');
      expect(sc.steps[1].keyword, StepKeyword.when);
      expect(sc.steps[1].fullText, 'Wenn ich den Benutzer "Alice" lösche');
      expect(sc.steps[2].keyword, StepKeyword.then);
      expect(sc.steps[2].fullText, 'Dann ist "Alice" nicht mehr vorhanden');
      expect(sc.steps[3].keyword, StepKeyword.and);
      expect(sc.steps[3].fullText, 'Und eine Erfolgsmeldung wird angezeigt');
      expect(sc.steps[4].keyword, StepKeyword.and);
      expect(sc.steps[4].fullText, 'Aber keine Fehlermeldung erscheint');

      // Outline under Rule in German
      expect(feature.scenarioOutlines, hasLength(1));
      final outline = feature.scenarioOutlines[0];
      expect(outline.name, 'Benutzer anlegen mit Rolle');
      final expanded = outline.expandToScenarios();
      expect(expanded, hasLength(2));
      expect(expanded[0].steps[0].text, 'ich bin als Administrator eingeloggt');
      expect(expanded[0].steps[1].text, 'ich einen Benutzer mit Rolle editor anlege');
      expect(expanded[0].steps[2].text, 'hat der Benutzer die Rolle editor');
      expect(expanded[1].steps[1].text, 'ich einen Benutzer mit Rolle viewer anlege');
    });

    test('supports Swedish (# language: sv)', () {
      const content = '''
# language: sv
Egenskap: E-handel
  Bakgrund:
    Givet att kassan är öppen

  Regel: Rabatter gäller endast medlemmar
    Scenario: Medlemsrabatt appliceras
      Givet att kunden är guldmedlem
      När kunden handlar för 100 kr
      Så blir slutbeloppet 80 kr
      Och kvittot visar 20 kr rabatt
      Men leveransavgiften kvarstår

    Abstrakt Scenario: Volymrabatt
      När kunden köper <antal> artiklar
      Så erhålls <rabatt> procent rabatt

      Exempel:
        | antal | rabatt |
        | 10    | 15     |
''';
      final feature = parseFeature(content, 'test_sv.feature');

      expect(feature.name, 'E-handel');
      expect(feature.background?.steps[0].keyword, StepKeyword.given);
      expect(feature.background?.steps[0].fullText, 'Givet att kassan är öppen');

      expect(feature.scenarios, hasLength(1));
      final sc = feature.scenarios[0];
      expect(sc.name, 'Medlemsrabatt appliceras');
      expect(sc.steps[0].keyword, StepKeyword.given);
      expect(sc.steps[0].fullText, 'Givet att kunden är guldmedlem');
      expect(sc.steps[1].keyword, StepKeyword.when);
      expect(sc.steps[1].fullText, 'När kunden handlar för 100 kr');
      expect(sc.steps[2].keyword, StepKeyword.then);
      expect(sc.steps[2].fullText, 'Så blir slutbeloppet 80 kr');
      expect(sc.steps[3].keyword, StepKeyword.and);
      expect(sc.steps[3].fullText, 'Och kvittot visar 20 kr rabatt');
      expect(sc.steps[4].keyword, StepKeyword.and);
      expect(sc.steps[4].fullText, 'Men leveransavgiften kvarstår');

      expect(feature.scenarioOutlines, hasLength(1));
      final expanded = feature.scenarioOutlines[0].expandToScenarios();
      expect(expanded, hasLength(1));
      expect(expanded[0].steps[0].text, 'kunden köper 10 artiklar');
      expect(expanded[0].steps[1].text, 'erhålls 15 procent rabatt');
    });

    test('supports Spanish (# language: es)', () {
      const content = '''
# language: es
Característica: Operaciones bancarias
  Antecedentes:
    Dado que el cajero tiene efectivo

  Regla: Límite diario de retiro
    Escenario: Retiro exitoso con tabla
      Dado que la cuenta tiene fondos:
        | cuenta | saldo |
        | 12345  | 500   |
      Cuando retiro 100 de la cuenta 12345
      Entonces el nuevo saldo es 400
      Y se emite un recibo
      Pero no se cobra comisión
''';
      final feature = parseFeature(content, 'test_es.feature');

      expect(feature.name, 'Operaciones bancarias');
      expect(feature.background?.steps[0].keyword, StepKeyword.given);
      expect(feature.background?.steps[0].fullText, 'Dado que el cajero tiene efectivo');

      expect(feature.scenarios, hasLength(1));
      final sc = feature.scenarios[0];
      expect(sc.name, 'Retiro exitoso con tabla');
      expect(sc.steps[0].dataTable, isNotNull);
      expect(sc.steps[0].dataTable!.headers, ['cuenta', 'saldo']);
      expect(sc.steps[0].dataTable!.rows[0], ['12345', '500']);

      expect(sc.steps[0].keyword, StepKeyword.given);
      expect(sc.steps[1].keyword, StepKeyword.when);
      expect(sc.steps[1].fullText, 'Cuando retiro 100 de la cuenta 12345');
      expect(sc.steps[2].keyword, StepKeyword.then);
      expect(sc.steps[2].fullText, 'Entonces el nuevo saldo es 400');
      expect(sc.steps[3].keyword, StepKeyword.and);
      expect(sc.steps[3].fullText, 'Y se emite un recibo');
      expect(sc.steps[4].keyword, StepKeyword.and);
      expect(sc.steps[4].fullText, 'Pero no se cobra comisión');
    });

    test('supports Japanese (# language: ja)', () {
      const content = '''
# language: ja
機能: 注文管理
  背景:
    前提 ユーザーがログインしている

  ルール: 在庫がある場合のみ注文可能
    シナリオ: 通常注文の成功
      前提 商品の在庫が10個ある
      もし ユーザーが商品を2個注文する
      ならば 注文が確定する
      かつ 在庫が8個になる

    シナリオアウトライン: 複数数量の注文
      もし ユーザーが商品を<数量>個注文する
      ならば 残り在庫は<残数>個になる

      例:
        | 数量 | 残数 |
        | 1    | 9    |
        | 3    | 7    |
''';
      final feature = parseFeature(content, 'test_ja.feature');

      expect(feature.name, '注文管理');
      expect(feature.background?.steps[0].keyword, StepKeyword.given);
      expect(feature.background?.steps[0].text, 'ユーザーがログインしている');

      expect(feature.scenarios, hasLength(1));
      final sc = feature.scenarios[0];
      expect(sc.name, '通常注文の成功');
      expect(sc.steps[0].keyword, StepKeyword.given);
      expect(sc.steps[0].text, '商品の在庫が10個ある');
      expect(sc.steps[1].keyword, StepKeyword.when);
      expect(sc.steps[1].text, 'ユーザーが商品を2個注文する');
      expect(sc.steps[2].keyword, StepKeyword.then);
      expect(sc.steps[2].text, '注文が確定する');
      expect(sc.steps[3].keyword, StepKeyword.and);
      expect(sc.steps[3].text, '在庫が8個になる');

      expect(feature.scenarioOutlines, hasLength(1));
      final outline = feature.scenarioOutlines[0];
      expect(outline.name, '複数数量の注文');
      final expanded = outline.expandToScenarios();
      expect(expanded, hasLength(2));
      expect(expanded[0].steps[0].text, 'ユーザーが商品を1個注文する');
      expect(expanded[0].steps[1].text, '残り在庫は9個になる');
      expect(expanded[1].steps[0].text, 'ユーザーが商品を3個注文する');
      expect(expanded[1].steps[1].text, '残り在庫は7個になる');
    });
  });
}
