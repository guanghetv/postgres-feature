# Performance Tune

### shared_buffers
    a reasonable starting value for shared_buffers is 25% of the memory in your system.
    but because PostgreSQL also relies on the operating system cache, 
it is unlikely that an allocation of more than 40% of RAM to shared_buffers 
will work better than a smaller amount.
    Larger settings for shared_buffers usually require a corresponding increase in max_wal_size, 
in order to spread out the process of writing large quantities of new or changed data 
over a longer period of time.