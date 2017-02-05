#if [[ ! -e ./vcpe-observer.py ]]; then
#    ln -s ../../xos-observer.py vcpe-observer.py
#fi

export XOS_DIR=/opt/xos
cp /root/setup/node_key $XOS_DIR/synchronizers/vsg/node_key
chmod 0600 $XOS_DIR/synchronizers/vsg/node_key
python vcpe-synchronizer.py  -C $XOS_DIR/synchronizers/vsg/vsg_synchronizer_config
