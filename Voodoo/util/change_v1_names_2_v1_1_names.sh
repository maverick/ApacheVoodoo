for i in `find . -name "*.pm"`
do
perl -p -i -e " s/Voodoo\:\:/Apache\:\:Voodoo\:\:/g; s/Voodoo\:\:Base/Voodoo/g; s/Table\:\:Beta/Table/g" $i
done
