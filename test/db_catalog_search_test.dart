import 'package:flutter_test/flutter_test.dart';
import 'package:irblaster_controller/utils/db_catalog_search.dart';

void main() {
  test('exact brands precede partial matches without changing identifiers', () {
    final search = DbCatalogSearch(['ASONY', 'SONYSAT', 'SONY', 'TCL']);
    expect(search.search(' sony '), ['SONY', 'SONYSAT', 'ASONY']);
    expect(search.search('tcl'), ['TCL']);
    expect(search.search(''), ['ASONY', 'SONYSAT', 'SONY', 'TCL']);
  });

  test('model formatting and word order do not hide matching models', () {
    final search = DbCatalogSearch([
      'RM - ED013',
      'RM-ED013(TV)',
      'RM-ED013(DVD)',
      '19 B 12 H(2 VERS.)',
    ]);
    expect(search.search('rm ed013'),
        ['RM - ED013', 'RM-ED013(TV)', 'RM-ED013(DVD)']);
    expect(search.search('tv rm-ed013'), ['RM-ED013(TV)']);
    expect(search.search('19b12h'), ['19 B 12 H(2 VERS.)']);
    expect(search.search('not in database'), isEmpty);
  });

  test('literal wildcards, non-Latin names and suffixes remain distinct', () {
    final search = DbCatalogSearch(['100%', '100A', 'Модель', 'TV-1', 'TV-10']);
    expect(search.search('%'), ['100%']);
    expect(search.search('модель'), ['Модель']);
    expect(search.search('TV1'), ['TV-1', 'TV-10']);
    expect(search.search('TV10'), ['TV-10']);
  });
}
