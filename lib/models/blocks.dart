import 'app_models.dart';

/// # Blockly Bloklar bazasi (Blockly Block Definitions)
///
/// Ushbu fayl ilovada ishlatiladigan barcha Blockly bloklarini aniqlaydi.
/// Bu yerda bloklarning tashqi ko'rinishi (JSON), kategoriyalari va
/// ularni yaratish logikasi (Factory) jamlangan.
///
/// ## Yangi blok qo'shish tartibi:
/// 1. **statementTypes** yoki **valueTypes** to'plamiga blok nomini qo'shing.
/// 2. **toolboxJson** metodida kerakli kategoriya ichiga blokni joylashtiring.
/// 3. **customBlockJsonArray** metodida blokning vizual ko'rinishini (JSON) yozing.
/// 4. **createBlock** metodida blokning boshlang'ich qiymatlarini (inputs/slots) aniqlang.
/// 5. **inferCategory** metodida blok qaysi turga tegishli ekanini ko'rsating.
class BlockDefinitions {
  /// Buyruq (Statement) turidagi bloklar ro'yxati.
  /// Bu bloklar ketma-ket ulanishi mumkin (yuqoridan va pastdan ulanish nuqtasi bor).
  static const Set<String> statementTypes = {
    'set_variable', // O'zgaruvchi yaratish
    'if', // Agar shart bo'lsa
    'if_else', // Agar/Aks holda
    'toast', // Xabar chiqarish (Toast)
    'snackbar', // Pastki xabar (Snackbar)
    'set_enabled', // Vidjetni yoqish/o'chirish
    'request_focus', // Vidjetga fokus berish
    'navigate_push', // Sahifaga o'tish
    'navigate_pop', // Orqaga qaytish
    'event_hat', // Boshlanish bloki (Hat)
  };

  /// Qiymat (Value) turidagi bloklar ro'yxati.
  /// Bu bloklar ma'lumot qaytaradi (chap/o'ng tomondan ulanish nuqtasi bor).
  static const Set<String> valueTypes = {
    'compare_eq', // Tenglik (==)
    'compare_ne', // Teng emas (!=)
    'compare_lt', // Kichik (<)
    'compare_lte', // Kichik yoki teng (<=)
    'compare_gt', // Katta (>)
    'compare_gte', // Katta yoki teng (>=)
    'logic_and', // VA (AND)
    'logic_or', // YOKI (OR)
    'logic_not', // EMAS (NOT)
    'bool_true', // rost (true)
    'bool_false', // yolg'on (false)
    'string_is_empty', // Matn bo'shligini tekshirish
    'string_not_empty', // Matn bo'sh emasligini tekshirish
  };

  /// Blok turini tekshirish uchun yordamchi metodlar
  static bool isStatementType(String type) => statementTypes.contains(type);
  static bool isValueType(String type) => valueTypes.contains(type);

  /// Barcha qo'llab-quvvatlanadigan bloklar
  static Set<String> get supportedTypes => {...statementTypes, ...valueTypes};

  /// Toolbox (Asboblar qutisi) konfiguratsiyasi.
  /// Bu yerda bloklar kategoriyalar bo'yicha ajratilgan.
  static Map<String, dynamic> toolboxJson() {
    return {
      'kind': 'categoryToolbox',
      'contents': [
        {
          'kind': 'category',
          'name': 'O\'zgaruvchi', // Variable
          'categorystyle': 'variable_category',
          'contents': [
            {'kind': 'block', 'type': 'set_variable'},
          ],
        },
        {
          'kind': 'category',
          'name': 'Boshqaruv', // Control
          'categorystyle': 'control_category',
          'contents': [
            {'kind': 'block', 'type': 'event_hat'},
            {'kind': 'block', 'type': 'if'},
            {'kind': 'block', 'type': 'if_else'},
          ],
        },
        {
          'kind': 'category',
          'name': 'Operatorlar', // Operators
          'categorystyle': 'operator_category',
          'contents': [
            {'kind': 'block', 'type': 'compare_eq'},
            {'kind': 'block', 'type': 'compare_ne'},
            {'kind': 'block', 'type': 'compare_lt'},
            {'kind': 'block', 'type': 'compare_lte'},
            {'kind': 'block', 'type': 'compare_gt'},
            {'kind': 'block', 'type': 'compare_gte'},
            {'kind': 'block', 'type': 'logic_and'},
            {'kind': 'block', 'type': 'logic_or'},
            {'kind': 'block', 'type': 'logic_not'},
            {'kind': 'block', 'type': 'bool_true'},
            {'kind': 'block', 'type': 'bool_false'},
            {'kind': 'block', 'type': 'string_is_empty'},
            {'kind': 'block', 'type': 'string_not_empty'},
          ],
        },
        {
          'kind': 'category',
          'name': 'Ko\'rinish', // View / Actions
          'categorystyle': 'view_category',
          'contents': [
            {'kind': 'block', 'type': 'toast'},
            {'kind': 'block', 'type': 'snackbar'},
            {'kind': 'block', 'type': 'set_enabled'},
            {'kind': 'block', 'type': 'request_focus'},
            {'kind': 'block', 'type': 'navigate_push'},
            {'kind': 'block', 'type': 'navigate_pop'},
          ],
        },
      ],
    };
  }

  /// Maxsus bloklar uchun JSON strukturalari.
  /// Bu yerda har bir blokning matni, kirish joylari (args) va ranglari aniqlanadi.
  static List<Map<String, dynamic>> customBlockJsonArray({
    required String defaultWidgetId,
    required String defaultPageId,
  }) {
    return [
      {
        'type': 'set_variable',
        'message0': 'o\'zgaruvchi %1 qiymati %2 bo\'lsin',
        'args0': [
          {'type': 'field_input', 'name': 'NAME', 'text': 'nomi'},
          {'type': 'field_input', 'name': 'VALUE', 'text': '0'},
        ],
        'previousStatement': null,
        'nextStatement': null,
        'colour': 20,
      },
      {
        'type': 'if',
        'message0': 'agar %1 bo\'lsa',
        'args0': [
          {'type': 'input_value', 'name': 'CONDITION', 'check': 'Boolean'},
        ],
        'message1': 'u holda %1',
        'args1': [
          {'type': 'input_statement', 'name': 'THEN'},
        ],
        'previousStatement': null,
        'nextStatement': null,
        'colour': 45,
      },
      {
        'type': 'if_else',
        'message0': 'agar %1 bo\'lsa',
        'args0': [
          {'type': 'input_value', 'name': 'CONDITION', 'check': 'Boolean'},
        ],
        'message1': 'u holda %1',
        'args1': [
          {'type': 'input_statement', 'name': 'THEN'},
        ],
        'message2': 'aks holda %1',
        'args2': [
          {'type': 'input_statement', 'name': 'ELSE'},
        ],
        'previousStatement': null,
        'nextStatement': null,
        'colour': 45,
      },
      {
        'type': 'event_hat',
        'message0': '%1 boshlanganda',
        'args0': [
          {'type': 'field_label', 'name': 'NAME', 'text': 'Harakat'},
        ],
        'nextStatement': null,
        'colour': 0,
        'hat': 'cap',
        'deletable': false,
      },

      {
        'type': 'compare_eq',
        'message0': '%1 == %2',
        'args0': [
          {'type': 'field_input', 'name': 'LEFT', 'text': '1'},
          {'type': 'field_input', 'name': 'RIGHT', 'text': '1'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'compare_ne',
        'message0': '%1 != %2',
        'args0': [
          {'type': 'field_input', 'name': 'LEFT', 'text': '1'},
          {'type': 'field_input', 'name': 'RIGHT', 'text': '2'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'compare_lt',
        'message0': '%1 < %2',
        'args0': [
          {'type': 'field_input', 'name': 'LEFT', 'text': '1'},
          {'type': 'field_input', 'name': 'RIGHT', 'text': '2'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'compare_lte',
        'message0': '%1 <= %2',
        'args0': [
          {'type': 'field_input', 'name': 'LEFT', 'text': '1'},
          {'type': 'field_input', 'name': 'RIGHT', 'text': '2'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'compare_gt',
        'message0': '%1 > %2',
        'args0': [
          {'type': 'field_input', 'name': 'LEFT', 'text': '2'},
          {'type': 'field_input', 'name': 'RIGHT', 'text': '1'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'compare_gte',
        'message0': '%1 >= %2',
        'args0': [
          {'type': 'field_input', 'name': 'LEFT', 'text': '2'},
          {'type': 'field_input', 'name': 'RIGHT', 'text': '1'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'logic_and',
        'message0': '%1 va %2',
        'args0': [
          {'type': 'input_value', 'name': 'LEFT', 'check': 'Boolean'},
          {'type': 'input_value', 'name': 'RIGHT', 'check': 'Boolean'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'logic_or',
        'message0': '%1 yoki %2',
        'args0': [
          {'type': 'input_value', 'name': 'LEFT', 'check': 'Boolean'},
          {'type': 'input_value', 'name': 'RIGHT', 'check': 'Boolean'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'logic_not',
        'message0': '%1 emas',
        'args0': [
          {'type': 'input_value', 'name': 'VALUE', 'check': 'Boolean'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'bool_true',
        'message0': 'rost',
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'bool_false',
        'message0': 'yolg\'on',
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'string_is_empty',
        'message0': '%1 bo\'sh bo\'lsa',
        'args0': [
          {'type': 'field_input', 'name': 'VALUE', 'text': ''},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'string_not_empty',
        'message0': '%1 bo\'sh bo\'lmasa',
        'args0': [
          {'type': 'field_input', 'name': 'VALUE', 'text': 'matn'},
        ],
        'output': 'Boolean',
        'colour': 120,
      },
      {
        'type': 'toast',
        'message0': 'Toast xabar %1',
        'args0': [
          {'type': 'field_input', 'name': 'MESSAGE', 'text': 'Salom'},
        ],
        'previousStatement': null,
        'nextStatement': null,
        'colour': 210,
      },
      {
        'type': 'snackbar',
        'message0': 'Snackbar xabar %1',
        'args0': [
          {'type': 'field_input', 'name': 'MESSAGE', 'text': 'Saqlandi'},
        ],
        'previousStatement': null,
        'nextStatement': null,
        'colour': 210,
      },
      {
        'type': 'set_enabled',
        'message0': 'Vidjet %1 holati %2 bo\'lsin',
        'args0': [
          {'type': 'field_input', 'name': 'WIDGET', 'text': defaultWidgetId},
          {'type': 'input_value', 'name': 'ENABLED', 'check': 'Boolean'},
        ],
        'previousStatement': null,
        'nextStatement': null,
        'colour': 210,
      },
      {
        'type': 'request_focus',
        'message0': 'Vidjet %1 ga fokus berish',
        'args0': [
          {'type': 'field_input', 'name': 'WIDGET', 'text': defaultWidgetId},
        ],
        'previousStatement': null,
        'nextStatement': null,
        'colour': 210,
      },
      {
        'type': 'navigate_push',
        'message0': 'Sahifaga o\'tish %1',
        'args0': [
          {'type': 'field_input', 'name': 'TARGET', 'text': defaultPageId},
        ],
        'previousStatement': null,
        'nextStatement': null,
        'colour': 210,
      },
      {
        'type': 'navigate_pop',
        'message0': 'Orqaga qaytish',
        'previousStatement': null,
        'nextStatement': null,
        'colour': 210,
      },
    ];
  }

  /// Dart tarafida `BlockModel` yaratish uchun Factory metodi.
  /// Blockly'dan qaytgan JSON ma'lumotlarini bizning modellarga o'girishda ishlatiladi.
  static BlockModel createBlock(String type, {required String id}) {
    final inputs = <String, BlockInputModel>{};
    final slots = <String, List<BlockModel>>{};

    switch (type) {
      case 'set_variable':
        inputs['name'] = const BlockInputModel(value: 'value');
        inputs['value'] = const BlockInputModel(value: '0');
        break;
      case 'if':
        slots['condition'] = [];
        slots['then'] = [];
        break;
      case 'if_else':
        slots['condition'] = [];
        slots['then'] = [];
        slots['else'] = [];
        break;
      case 'event_hat':
        inputs['name'] = const BlockInputModel(value: 'Harakat');
        break;
      case 'toast':
      case 'snackbar':
        inputs['message'] = const BlockInputModel(value: '');
        break;
      case 'set_enabled':
        inputs['widgetId'] = const BlockInputModel(value: 'button1');
        inputs['enabled'] = const BlockInputModel(value: true);
        break;
      case 'request_focus':
        inputs['widgetId'] = const BlockInputModel(value: 'button1');
        break;
      case 'navigate_push':
        inputs['targetPage'] = const BlockInputModel(value: '');
        break;
      case 'compare_eq':
      case 'compare_ne':
      case 'compare_lt':
      case 'compare_lte':
      case 'compare_gt':
      case 'compare_gte':
        inputs['left'] = const BlockInputModel(value: '1');
        inputs['right'] = const BlockInputModel(value: '1');
        break;
      case 'logic_and':
      case 'logic_or':
        inputs['left'] = const BlockInputModel(value: true);
        inputs['right'] = const BlockInputModel(value: true);
        break;
      case 'logic_not':
        inputs['value'] = const BlockInputModel(value: true);
        break;
      case 'string_is_empty':
      case 'string_not_empty':
        inputs['value'] = const BlockInputModel(value: '');
        break;
    }

    return BlockModel(
      id: id,
      type: type,
      category: inferCategory(type),
      inputs: inputs,
      slots: slots,
    );
  }

  /// Blok turiga qarab uning kategoriyasini aniqlash.
  /// Ranglar va Toolbox'dagi o'rni uchun xizmat qiladi.
  static BlockCategory inferCategory(String type) {
    if (statementTypes.contains(type)) {
      if (type == 'if' || type == 'if_else' || type == 'event_hat') {
        return BlockCategory.control;
      }
      if (type == 'set_variable') return BlockCategory.variable;
      return BlockCategory.view;
    }
    return BlockCategory.operator;
  }
}
