<mashrc>
    <syslog/>
    <parsers>
        <ballast>
            <getopt>conf_file|c,l</getopt>
            <argument>
                <count op="ge">2</count>
            </argument>
            <option>
                <unset name="c"/>
                <unset name="conf_file"/>
                <set name="l"/>
            </option>
        </ballast>
        <bbcp>
            <argument>
                <count>2</count>
                <regex index="1">^(SRC|SNK)$</regex>
            </argument>
        </bbcp>
        <bbftpd>
            <getopt>bcfpsuvm:w:e:l:R:</getopt>
            <argument>
                <count>1</count>
            </argument>
            <option>
                <set name="s"/>
                <regex>^(?!.*(\n|^)[bcpuvwR])</regex>
                <force name="f">1</force>
            </option>
        </bbftpd>
        <md5sum>
            <getopt>b,c,t,status,w|warn,help,version</getopt>
        </md5sum>
        <mesh-getmp>
            <!-- the comma is here on purpose to force Getopt::Long -->
            <getopt>local,</getopt>
            <argument>
                <count>2</count>
            </argument>
        </mesh-getmp>
        <mesh-keygen>
            <argument>
                <count>1</count>
            </argument>
            <getopt>init,init-add,read,time=s,user=s</getopt>
        </mesh-keygen>
        <mesh-keykill>
            <argument>
                <count op="le">2</count>
            </argument>
            <getopt>all,user=s</getopt>
        </mesh-keykill>
        <mesh-setmp>
            <getopt>away=s,home=s,homemap=s,local</getopt>
        </mesh-setmp>
        <msum>
            <getopt>b,buffer-size=i,c,check-tree,direct-read,double-buffer,fadvise,hash-leaf-size=i,hash-type=s,help,length=i,listen-port=i,manager-host=s,manager-port=i,mpi,offset=i,password-file=s,split-size=i,t,threads=i,status,w|warn,help,version</getopt>
        </msum>
        <qdel>
            <getopt>W:</getopt>
            <argument>
                <regex>^(?!.*@)</regex>
            </argument>
        </qdel>
        <qstat>
            <getopt>afinpqrstBGJMQRu:W:</getopt>
        </qstat>
        <qsub>
            <getopt>h,z,I,V,a=s,c=s,e=s,j=s,k=s,l=s@,m=s,o=s,p=s,q=s,r=s,u=s,v=s,A=s,C=s,J=s,M=s,N=s,S=s,W=s@</getopt>
            <argument>
                <count op="ge">2</count>
            </argument>
            <option>
                <unset name="I"/>
                <unset name="S"/>
                <unset name="u"/>
                <unset name="V"/>
                <regex name="e">^(?!.*:)</regex>
                <regex name="o">^(?!.*:)</regex>
                <regex name="v">^(?!.*(LD_|_RLD_))</regex>
                <regex name="W">^(?!.*(interactive|stage))</regex>
            </option>
        </qsub>
        <rsync>
            <getopt>8-bit-output,8,acls,A,address=s,append,append-verify,archive,a,backup,b,backup-dir=s,block-size,B,blocking-io,bwlimit=i,checksum,c,checksum-seed=i,chmod=s,compare-dest=s,compress,z,compress-level=i,config=s,config=s,contimeout=i,copy-dest=s,copy-dirlinks,k,copy-links,L,copy-unsafe-links,cvs-exclude,C,daemon,del,delay-updates,delete,delete-after,delete-before,delete-delay,delete-during,delete-excluded,detach,devices,dirs,d,dry-run,n,exclude=s,exclude-from=s,executability,E,existing,fake-super,files-from=s,filter=s,f=s,force,from0,0,fuzzy,y,group,g,hard-links,H,help,h,human-readable,h,i-d,i-r,iconv=s,ignore-errors,ignore-existing,ignore-non-existing,ignore-times,I,implied-dirs,inc-recursive,include=s,include-from=s,inplace,ipv4,4,ipv6,6,itemize-changes,i,keep-dirlinks,K,link-dest=s,links,l,list-only,log-file=s,log-file-format=s,log-format=s,max-delete=i,max-size=s,min-size=s,modify-window=i,motd,no-8,no-8-bit-output,no-A,no-D,no-H,no-O,no-R,no-S,no-W,no-X,no-acls,no-append,no-backup,no-blocking-io,no-bwlimit,no-c,no-checksum,no-compress,no-contimeout,no-d,no-delay-updates,no-detach,no-devices,no-dirs,no-force,no-from0,no-fuzzy,no-g,no-group,no-h,no-hard-links,no-human-readable,no-i,no-i-d,no-i-r,no-iconv,no-ignore-errors,no-implied-dirs,no-inc-recursive,no-inplace,no-itemize-changes,no-l,no-links,no-m,no-motd,no-numeric-ids,no-o,no-omit-dir-times,no-one-file-system,x,no-owner,no-p,no-partial,no-perms,no-progress,no-protect-args,no-prune-empty-dirs,no-r,no-recursive,no-relative,no-s,no-sparse,no-specials,no-super,no-t,no-timeout,no-times,no-v,no-verbose,no-whole-file,no-x,x,no-xattrs,no-y,no-z,numeric-ids,old-d,old-dirs,omit-dir-times,O,one-file-system,x,only-write-batch=s,out-format=s,owner,o,partial,partial-dir=s,password-file=s,perms,p,port=i,progress,protect-args,s,protocol=i,prune-empty-dirs,m,qsort,quiet,q,read-batch=s,recursive,r,relative,R,remove-sent-files,remove-source-files,rsh=s,e=s,rsync-path=s,safe-links,sender,server,size-only,skip-compress=s,sockopts=s,sparse,S,specials,stats,suffix=s,super,temp-dir=s,T=s,timeout=i,times,t,update,u,verbose,v,version,whole-file,W,write-batch=s,xattrs,X,D,F,P</getopt>
            <option>
                <set name="server"/>
                <unset name="rsh"/>
                <unset name="rsync-path"/>
                <unset name="daemon"/>
            </option>
            <argument>
                <count op="le">3</count>
            </argument>
        </rsync>
        <save.alert>
            <argument>
                <count op="le">2</count>
            </argument>
            <getopt>u,O,T,l=i,g=s,h=s,s=s,t=s</getopt>
        </save.alert>
        <scp>
            <getopt>dfpqrtv</getopt>
            <argument>
                <count op="ge">2</count>
            </argument>
            <option>
                <regex>^(?=.*(^|\n)[ft])</regex>
                <regex>^(?!.*[ft].*[ft])</regex>
            </option>
        </scp>
        <sftp>
            <argument>
                <count>1</count>
                <replace index="0" regex="$">-server</replace>
            </argument>
        </sftp>
        <shift-mgr>
            <getopt>alive,get,history,host=s,id=s,lock,mounts,pid=i,put,restart,search=s,shift-mgr,state=s,stats,status:s,stop</getopt>
            <argument>
                <count>1</count>
            </argument>
        </shift-mgr>
        <tar>
            <getopt>A|catenate|concatenate,atime-preserve,b|block-size=i,B|read-full-blocks,block-compress,c|create,C|directory=s,checkpoint,d|diff|compare,delete,exclude=s,f|file=s,F|info-script|new-volume-script=s,force-local,G|incremental,g|listed-incremental=s,h|dereference,i|ignore-zeros,ignore-failed-read,j|bzip2|bunzip2,k|keep-old-files,K|starting-file=s,l|one-file-system,L|tape-length=i,m|modification-time,M|multi-volume,N|after-date|newer=s,null,o|old-archive|portability,O|to-stdout,p|same-permissions|preserve-permissions,P|absolute-paths,preserve,r|append,R|record-number,remove-files,s|same-order|preserve-order,S|sparse,same-owner,t|list,T|files-from=s,totals,u|update,use-compress-program=s,v|verbose,V|label=s,version,w|interactive|confirmation,W|verify,x|extract|get,X|exclude-from=s,Z|compress|uncompress,z|gzip|ungzip,0l|0m|0h,1l|1m|1h,2l|2m|2h,3l|3m|3h,4l|4m|4h,5l|5m|5h,6l|6m|6h,7l|7m|7h</getopt>
            <option>
                <regex name="f">^(?!.*:)</regex>
                <unset name="use-compress-program"/>
            </option>
            <argument>
                <regex>^(?!.*:)</regex>
            </argument>
        </tar>
    </parsers>
    <policies>
        <default>
            <group>
                <deny>
                    <MESHCONF_mesh_group/>
                </deny>
            </group>
            <proxies>
                <ssh>
                    <directory>/usr/bin</directory>
                    <!-- limit commands to specific set of hosts, if desired
                    <argument>
                        <regex index="1">host1|host2</regex>
                    </argument>
                    -->
                    <!-- SSH port number on resource -->
                    <port>22</port>
                    <environment>
                        <set name="MESH_PUBKEY"/>
                    </environment>
                    <commands>
                        <!-- commands that may execute on resources
                        <test>
                            <directory>/usr/bin</directory>
                        </test>
                        -->
                    </commands>
                </ssh>
                <none>
                    <environment>
                        <set name="MESH_PUBKEY"/>
                    </environment>
                    <commands>
                        <mesh-getmp>
                            <directory>MESHCONF_prefix_dir/bin</directory>
                        </mesh-getmp>
                        <mesh-keykill>
                            <directory>MESHCONF_prefix_dir/bin</directory>
                            <option>
                                <unset name="all"/>
                                <unset name="user"/>
                            </option>
                        </mesh-keykill>
                        <mesh-keytime>
                            <directory>MESHCONF_prefix_dir/bin</directory>
                            <argument>
                                <count>1</count>
                            </argument>
                        </mesh-keytime>
                        <mesh-setmp>
                            <directory>MESHCONF_prefix_dir/bin</directory>
                        </mesh-setmp>
                        <mesh-update>
                            <directory>MESHCONF_prefix_dir/bin</directory>
                        </mesh-update>
                    </commands>
                </none>
                <none>
                    <environment>
                        <unset name="MESH_PUBKEY"/>
                    </environment>
                    <commands>
                        <mesh-keygen>
                            <directory>MESHCONF_prefix_dir/bin</directory>
                            <option>
                                <unset name="init"/>
                                <unset name="init-add"/>
                                <unset name="read"/>
                                <unset name="user"/>
                                <!-- time that keys are valid -->
                                <force name="time">MESHCONF_key_days</force>
                            </option>
                        </mesh-keygen>
                        <mesh-keykill>
                            <directory>MESHCONF_prefix_dir/bin</directory>
                            <argument>
                                <count>1</count>
                            </argument>
                            <option>
                                <set name="all"/>
                                <unset name="user"/>
                            </option>
                        </mesh-keykill>
                        <mesh-update>
                            <directory>MESHCONF_prefix_dir/bin</directory>
                        </mesh-update>
                    </commands>
                </none>
            </proxies>
        </default>
        <admin>
            <user>
                <allow>
                    <!-- list of admin users
                    <user1/>
                    -->
                </allow>
            </user>
            <environment>
                <unset name="MESH_PUBKEY"/>
            </environment>
            <proxies>
                <none>
                    <commands>
                        <bash>
                            <directory>/bin</directory>
                            <argument>
                                <count>1</count>
                            </argument>
                        </bash>
                        <scp>
                            <directory>/usr/bin</directory>
                        </scp>
                    </commands>
                </none>
            </proxies>
        </admin>
        <getkey>
            <group>
                <allow>
                    <MESHCONF_mesh_group/>
                </allow>
            </group>
            <environment>
                <set name="MESH_PUBKEY"/>
            </environment>
            <proxies>
                <none>
                    <commands>
                        <mesh-getkey>
                            <directory>MESHCONF_prefix_dir/sbin</directory>
                            <argument>
                                <count>2</count>
                            </argument>
                        </mesh-getkey>
                    </commands>
                </none>
            </proxies>
        </getkey>
    </policies>
</mashrc>

