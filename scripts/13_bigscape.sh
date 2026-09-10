[Wed Sep  9 08:09:00 PM CDT 2026] Running BiG-SCAPE on antiSMASH output structure...



   - - Processing input files - -
 Including files with one or more of the following strings in their filename: 'region'
 Skipping files with one or more of the following strings in their filename: 'final'

 Trying to read bundled MIBiG BGCs as reference
Traceback (most recent call last):
  File "/usr/local/bin/bigscape", line 10, in <module>
    sys.exit(main())
  File "/usr/local/lib/python3.7/site-packages/bigscape/__main__.py", line 5, in main
    bigscape.main()
  File "/usr/local/lib/python3.7/site-packages/bigscape/bigscape.py", line 2335, in main
    extractedbgc = mibig_zip.extract(fname,path=mibig_path)
  File "/usr/local/lib/python3.7/zipfile.py", line 1577, in extract
    return self._extract_member(member, path, pwd)
  File "/usr/local/lib/python3.7/zipfile.py", line 1640, in _extract_member
    os.makedirs(upperdirs)
  File "/usr/local/lib/python3.7/os.py", line 221, in makedirs
    mkdir(name, mode)
OSError: [Errno 30] Read-only file system: '/usr/local/lib/python3.7/site-packages/bigscape/Annotated_MIBiG_reference/MIBiG_3.1_final'
