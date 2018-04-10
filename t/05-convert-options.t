#!/perl

use strict;
use warnings;

use Test::Most;

use FindBin qw/ $Bin /;
use lib "$Bin/lib";


use_ok 'DBIx::Result::Convert::JSONSchema';
use_ok 'Test::SchemaMock';

my $schema_mock = Test::SchemaMock->new();
my $schema      = $schema_mock->schema;

isa_ok
    my $converter = DBIx::Result::Convert::JSONSchema->new(
        schema        => $schema,
        schema_source => 'MySQL',
    ),
    'DBIx::Result::Convert::JSONSchema';

my $json_schema = $converter->get_json_schema('MySQLTypeTest', {
    decimals_to_pattern             => 1,
    has_schema_property_description => 0,
    allow_additional_properties     => 1,
    overwrite_schema_property_keys  => {
        char     => 'cat',
        datetime => 'another',
    },
    overwrite_schema_properties     => {
        enum => {
            _action => 'merge',
            type    => 'dog',
            new_key => 'value',
        },
        blob => {
            _action => 'overwrite',
            new_prop_1 => 1,
            new_prop_2 => 2,
        },
    },
    exclude_required                => [ qw/ tinytext / ],
    exclude_properties              => [ qw/ binary / ],
    include_required                => [ qw/ year time / ],
});

is $json_schema->{properties}->{decimal}->{type}, 'string', 'decimal converted to string type';
ok $json_schema->{properties}->{decimal}->{pattern}, 'got set pattern for decimal';

# No description set
ok ! exists $json_schema->{properties}->{ $_ }->{description}, "-- description does not exist for key $_"
    for keys %{ $json_schema->{properties} };

is $json_schema->{additional_properties}, 1, 'allow additional properties in JSON schema';

ok ! exists $json_schema->{properties}->{char}, 'char key no longer exists';
ok ! exists $json_schema->{properties}->{datetime}, 'datetime key no longer exists';
ok exists $json_schema->{properties}->{cat}, 'cat key exists in JSON schema';
ok exists $json_schema->{properties}->{another}, 'another key exists in JSON schema';

is $json_schema->{properties}->{enum}->{type}, 'dog', 'enum now has type of dog';
ok $json_schema->{properties}->{enum}->{new_key}, 'enum contains new key';

is scalar @{ $json_schema->{required} }, 2, 'contains 2 required properties';
cmp_bag $json_schema->{required}, [ qw/ year time / ], 'got two expected required schema properties';

ok ! exists $json_schema->{properties}->{binary}, 'binary key got removed from JSON schema';

subtest 'different result for merge or overwrite property _action' => sub {

    # for 'enum' expecting keys to be merged
    is_deeply $json_schema->{properties}->{enum}, {
        type    => 'dog',
        new_key => 'value',
        enum    => [ qw/ X Y Z / ],
    }, 'got enum item with merged properties';

    # for 'blob' expecting all keys to be overwritten
    is_deeply $json_schema->{properties}->{blob}, {
        new_prop_1 => 1,
        new_prop_2 => 2,
    }, 'got blob item with all properties overwritten';

};

done_testing;
