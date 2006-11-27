rm -rf /tmp/voodoo_dist
mkdir -p /tmp/voodoo_dist/lib/Apache

cp -r * /tmp/voodoo_dist

cp -r ../Voodoo* /tmp/voodoo_dist/lib/Apache
cp -r ../bin /tmp/voodoo_dist/bin

cd /tmp/voodoo_dist

rm prepare_dist.sh
rm lib/Apache/Voodoo/MyConfig.pm

perl Makefile.PL
make && make test && make dist
