import 'package:flutter_test/flutter_test.dart';

import 'package:active/data/datasources/database_helper.dart';

/// The analytical-query tool lets the model author SQL, so validation is a
/// security boundary: anything that could mutate data must be rejected.
void main() {
  String? check(String sql) => DatabaseHelper.validateSelectOnly(sql);

  group('validateSelectOnly accepts', () {
    test('a plain SELECT', () {
      expect(check('SELECT * FROM activities'), isNull);
    });

    test('a SELECT with a trailing semicolon', () {
      expect(check('SELECT name FROM activities;'), isNull);
    });

    test('a lowercase select', () {
      expect(check('select count(*) from records'), isNull);
    });

    test('a CTE starting with WITH', () {
      expect(
        check('WITH daily AS (SELECT date(timestamp) d FROM records) '
            'SELECT d FROM daily'),
        isNull,
      );
    });

    test('a join with aggregates and date functions', () {
      expect(
        check("SELECT a.name, strftime('%w', r.timestamp) AS dow, "
            'SUM(r.quantity) FROM records r '
            'JOIN activities a ON a.id = r.activity_id GROUP BY a.name, dow'),
        isNull,
      );
    });
  });

  group('validateSelectOnly rejects', () {
    test('an empty query', () {
      expect(check('   '), contains('empty'));
    });

    test('a bare DELETE', () {
      expect(check('DELETE FROM records'), contains('SELECT'));
    });

    test('an UPDATE', () {
      expect(check('UPDATE activities SET name = "x"'), contains('SELECT'));
    });

    test('a DROP TABLE', () {
      expect(check('DROP TABLE activities'), contains('SELECT'));
    });

    test('a statement stacked after a SELECT', () {
      final result = check('SELECT 1; DELETE FROM records');
      expect(result, contains('single statement'));
    });

    test('a stacked statement hidden behind a trailing semicolon', () {
      expect(
        check('SELECT 1; DROP TABLE activities;'),
        contains('single statement'),
      );
    });

    test('a mutation hidden in a line comment', () {
      // The comment is stripped, leaving the stacked DELETE exposed.
      expect(
        check('SELECT 1 -- harmless\n; DELETE FROM records'),
        contains('single statement'),
      );
    });

    test('a DELETE embedded in a subquery', () {
      expect(
        check('SELECT * FROM activities WHERE id IN '
            '(SELECT activity_id FROM records) AND 1=1 UNION DELETE'),
        contains('delete'),
      );
    });

    test('PRAGMA statements', () {
      expect(check('PRAGMA table_info(activities)'), contains('SELECT'));
    });

    test('ATTACH, which could reach another database file', () {
      expect(
        check("SELECT 1 WHERE 1=1 AND ATTACH DATABASE 'x' AS y"),
        contains('attach'),
      );
    });

    test('INSERT via a CTE', () {
      expect(
        check('WITH x AS (SELECT 1) INSERT INTO records VALUES (1,1,1,1)'),
        contains('insert'),
      );
    });
  });

  group('validateSelectOnly does not false-positive', () {
    test('on a forbidden word appearing inside a string literal', () {
      // "delete" here is data, not a keyword.
      expect(check("SELECT * FROM activities WHERE name = 'delete'"), isNull);
    });

    test('on a column name that merely contains a keyword substring', () {
      // "created_at" contains "create" but only as a substring, and word
      // boundaries must not treat it as the CREATE keyword.
      expect(check('SELECT created_at FROM activities'), isNull);
    });
  });
}
