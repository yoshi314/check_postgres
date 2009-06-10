#!perl

## Test the "same_schema" action

use 5.006;
use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 31;
use lib 't','.';
use CP_Testing;

use vars qw/$dbh1 $dbh2 $SQL $t/;

my $cp1 = CP_Testing->new({ default_action => 'same_schema' });
my $cp2 = CP_Testing->new({ default_action => 'same_schema',
                            dbdir => $cp1->{dbdir} . '2' });

$dbh1 = $cp1->test_database_handle();
$dbh1->{AutoCommit} = 1;
eval { $dbh1->do(q{CREATE USER alternate_owner}, { RaiseError => 0, PrintError => 0 }); };
$dbh2 = $cp2->test_database_handle();
$dbh2->{AutoCommit} = 1;
eval { $dbh2->do(q{CREATE USER alternate_owner}, { RaiseError => 0, PrintError => 0 }); };

my $S = q{Action 'same_schema'};
my $label = 'POSTGRES_SAME_SCHEMA';

SKIP: {
    skip 'shortcut', 26;
$t = qq{$S fails when called with an invalid option};
like ($cp1->run('foobar=12'),
      qr{^\s*Usage:}, $t);

$t = qq{$S succeeds with two empty databases};
#local($CP_Testing::DEBUG) = 1;
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label OK}, $t);


#/////////// Users

$t = qq{$S fails when first schema has an extra user};
$dbh1->do(q{CREATE USER user_1_only});
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*Items not matched: 1\b.*Users in 1 but not 2: user_1_only},
      $t);
$dbh1->do(q{DROP USER user_1_only});

$t = qq{$S fails when second schema has an extra user};
$dbh2->do(q{CREATE USER user_2_only});
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*Items not matched: 1\b.*Users in 2 but not 1: user_2_only},
      $t);
$dbh2->do(q{DROP USER user_2_only});

#/////////// Schemas

$t = qq{$S fails when first schema has an extra schema};
$dbh1->do(q{CREATE SCHEMA schema_1_only});
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*Items not matched: 1\b.*Schema in 1 but not 2: schema_1_only},
      $t);

$t = qq{$S succeeds when noschema filter used};
like ($cp1->run(qq{--warning=noschema --dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label OK}, $t);

$t = qq{$S fails when schemas have different owners};
$dbh1->do(q{ALTER SCHEMA schema_1_only OWNER TO alternate_owner});
$dbh2->do(q{CREATE SCHEMA schema_1_only});
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*Items not matched: 1\b.*Schema schema_1_only owned by alternate_owner},
      $t);

$dbh1->do(q{DROP SCHEMA schema_1_only});
$dbh2->do(q{DROP SCHEMA schema_1_only});

$t = qq{$S fails when second schema has an extra schema};
$dbh2->do(q{CREATE SCHEMA schema_2_only});
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*Items not matched: 1\b.*Schema in 2 but not 1: schema_2_only},
      $t);

$t = qq{$S succeeds when noschema filter used};
like ($cp1->run(qq{--warning=noschema --dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label OK}, $t);

$t = qq{$S fails when schemas have different owners};
$dbh2->do(q{ALTER SCHEMA schema_2_only OWNER TO alternate_owner});
$dbh1->do(q{CREATE SCHEMA schema_2_only});
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*Items not matched: 1\b.*Schema schema_2_only owned by check_postgres_testing},
      $t);
$dbh1->do(q{DROP SCHEMA schema_2_only});
$dbh2->do(q{DROP SCHEMA schema_2_only});

#/////////// Tables

$t = qq{$S fails when first schema has an extra table};
$dbh1->do(q{CREATE TABLE table_1_only (a int)});
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*Items not matched: 1\b.*Table in 1 but not 2: public.table_1_only},
      $t);

$t = qq{$S succeeds when notables filter used};
like ($cp1->run(qq{--warning=notables --dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label OK}, $t);

$t = qq{$S fails when tables have different owners};
$dbh1->do(q{ALTER TABLE table_1_only OWNER TO alternate_owner});
$dbh2->do(q{CREATE TABLE table_1_only (a int)});
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*Items not matched: 1\b.*Table public.table_1_only owned by alternate_owner},
      $t);
$dbh1->do(q{DROP TABLE table_1_only});
$dbh2->do(q{DROP TABLE table_1_only});

$t = qq{$S fails when second schema has an extra table};
$dbh2->do(q{CREATE TABLE table_2_only (a int)});
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*Items not matched: 1\b.*Table in 2 but not 1: public.table_2_only},
      $t);

$t = qq{$S succeeds when notables filter used};
like ($cp1->run(qq{--warning=notables --dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label OK}, $t);

$t = qq{$S fails when tables have different owners};
$dbh2->do(q{ALTER TABLE table_2_only OWNER TO alternate_owner});
$dbh1->do(q{CREATE TABLE table_2_only (a int)});
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*Items not matched: 1\b.*Table public.table_2_only owned by check_postgres_testing},
      $t);
$dbh1->do(q{DROP TABLE table_2_only});
$dbh2->do(q{DROP TABLE table_2_only});

#/////////// Sequences

$t = qq{$S fails when first schema has an extra sequence};
$dbh1->do(q{CREATE SEQUENCE sequence_1_only});
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*Items not matched: 1\b.*Sequence in 1 but not 2: public.sequence_1_only},
      $t);

$t = qq{$S succeeds when nosequences filter used};
like ($cp1->run(qq{--warning=nosequences --dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label OK}, $t);

$dbh1->do(q{DROP SEQUENCE sequence_1_only});

$t = qq{$S fails when second schema has an extra sequence};
$dbh2->do(q{CREATE SEQUENCE sequence_2_only});
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*Items not matched: 1\b.*Sequence in 2 but not 1: public.sequence_2_only},
      $t);

$t = qq{$S succeeds when nosequences filter used};
like ($cp1->run(qq{--warning=nosequences --dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label OK}, $t);

$dbh2->do(q{DROP SEQUENCE sequence_2_only});

#/////////// Views

$t = qq{$S fails when first schema has an extra view};
$dbh1->do(q{CREATE VIEW view_1_only AS SELECT 1});
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*Items not matched: 1\b.*View in 1 but not 2: public.view_1_only},
      $t);

$t = qq{$S succeeds when noviews filter used};
like ($cp1->run(qq{--warning=noviews --dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label OK}, $t);

$dbh1->do(q{DROP VIEW view_1_only});

$t = qq{$S fails when second schema has an extra view};
$dbh2->do(q{CREATE VIEW view_2_only AS SELECT 1});
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*Items not matched: 1\b.*View in 2 but not 1: public.view_2_only},
      $t);

$t = qq{$S succeeds when noviews filter used};
like ($cp1->run(qq{--warning=noviews --dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label OK}, $t);

$dbh2->do(q{DROP VIEW view_2_only});

#/////////// Triggers

$dbh1->do(q{CREATE TABLE table_w_trigger (a int)});
$dbh2->do(q{CREATE TABLE table_w_trigger (a int)});

$dbh1->do(q{CREATE TRIGGER trigger_on_table BEFORE INSERT ON table_w_trigger EXECUTE PROCEDURE flatfile_update_trigger()});

$t = qq{$S fails when first schema has an extra trigger};
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*?Trigger in 1 but not 2: trigger_on_table},
      $t);

$t = qq{$S succeeds when notriggers filter used};
like ($cp1->run(qq{--warning=notriggers --dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label OK}, $t);

$dbh1->do(q{DROP TABLE table_w_trigger});
$dbh2->do(q{DROP TABLE table_w_trigger});
}

#/////////// Constraints

$dbh1->do(q{CREATE TABLE table_w_constraint (a int)});
$dbh2->do(q{CREATE TABLE table_w_constraint (a int)});

$dbh1->do(q{ALTER TABLE table_w_constraint ADD CONSTRAINT constraint_of_a CHECK(a > 0)});

$t = qq{$S fails when first schema has an extra constraint};
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*?Table public.table_w_constraint on 1 has constraint public.constraint_of_a on column a, but 2 does not},
      $t);

$dbh2->do(q{ALTER TABLE table_w_constraint ADD CONSTRAINT constraint_of_a CHECK(a < 0)});

$t = qq{$S fails when tables have differing constraints};
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*?1 differs from 2 \("CHECK \(a > 0\)" vs. "CHECK \(a < 0\)"\)},
      $t);

$dbh2->do(q{ALTER TABLE table_w_constraint DROP CONSTRAINT constraint_of_a});

$t = qq{$S fails when one table is missing a constraint};
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*?Table public.table_w_constraint on 1 has constraint public.constraint_of_a on column a, but 2 does not},
      $t);

$dbh1->do(q{CREATE TABLE table_w_another_cons (a int)});
$dbh2->do(q{CREATE TABLE table_w_another_cons (a int)});
$dbh2->do(q{ALTER TABLE table_w_another_cons ADD CONSTRAINT constraint_of_a CHECK(a > 0)});

$t = qq{$S fails when similar constraints are attached to differing tables};
like ($cp1->run(qq{--dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label CRITICAL.*?Constraint public.constraint_of_a is applied to public.table_w_constraint on 1, but to public.table_w_another_cons on 2},
      $t);

$dbh1->do(q{DROP TABLE table_w_another_cons});
$dbh2->do(q{DROP TABLE table_w_another_cons});

$t = qq{$S succeeds when noconstraints filter used};
like ($cp1->run(qq{--warning=noconstraints --dbhost2=$cp2->{shorthost} --dbuser2=$cp2->{testuser}}),
      qr{^$label OK}, $t);

$dbh1->do(q{DROP TABLE table_w_constraint});
$dbh2->do(q{DROP TABLE table_w_constraint});

#/////////// Functions


exit;
