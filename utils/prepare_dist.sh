rm -rf /tmp/voodoo_dist
mkdir -p /tmp/voodoo_dist/lib/Apache

cp -r * /tmp/voodoo_dist

cp -r ../Voodoo* /tmp/voodoo_dist/lib/Apache

cd /tmp/voodoo_dist

perl Makefile.PL
make && make test && make dist
