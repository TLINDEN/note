use ExtUtils::MakeMaker;

WriteMakefile(
              'NAME'         => 'NOTEDB',
              'VERSION_FROM' => 'NOTEDB.pm', # finds $VERSION
              'EXE_FILES'    => [ 'bin/note' ],
);
