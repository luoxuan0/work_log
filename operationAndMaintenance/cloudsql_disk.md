## cloud-sql 磁盘释放

### 问题

- 20250912发现近期触发自动扩容，24小时内出现3次，时间间隔越来越短
- 考虑服务稳定性（cloudsql在4小时内只能扩容一次25G，如果扩容后4小时内磁盘空间不足，那么数据将无法写入），磁盘空间成本，进行磁盘空间释放

### 分析

```sql

-- root账号
-- 查看各表磁盘使用情况

mysql> select table_schema, table_name, (data_length/1024/1024/1024) as data_mb , (index_length/1024/1024/1024) as index_mb, ((data_length+index_length)/1024/1024/1024) as all_mb, table_rows from information_schema.tables where table_schema = 'trackingdb' order by all_mb DESC limit 20;
+--------------+--------------------------------------+------------------+-----------------+------------------+------------+
| TABLE_SCHEMA | TABLE_NAME                           | data_mb          | index_mb        | all_mb           | TABLE_ROWS |
+--------------+--------------------------------------+------------------+-----------------+------------------+------------+
| trackingdb   | tr_tracking_info_58126_58126         | 409.846878051758 | 16.359405517578 | 426.206283569336 |   29653179 |
| trackingdb   | tr_tracking_info_218001_218500       | 131.978729248047 |  8.317718505859 | 140.296447753906 |   20076841 |
| trackingdb   | tr_express_statistics_bitmap_min     |  61.534393310547 | 74.646286010742 | 136.180679321289 |  394687957 |
| trackingdb   | tr_user_cost_deducte_log             |  73.315429687500 | 55.420349121094 | 128.735778808594 |  401354890 |
| trackingdb   | tr_trackinfo_effective_for_rule      | 100.903320312500 |  6.044921875000 | 106.948242187500 |    9247239 |
| trackingdb   | tr_tracking_info_224501_225000       |  88.274093627930 |  7.161407470703 |  95.435501098633 |   19062146 |
| trackingdb   | tr_user_cost_rd_log                  |  80.471679687500 |  7.507781982422 |  87.979461669922 |  362191630 |
| trackingdb   | tr_tracking_number_middle_ups        |  27.093750000000 | 59.208908081055 |  86.302658081055 |  107211892 |
| trackingdb   | tr_user_admin_association            |  29.527282714844 | 39.882705688477 |  69.409988403320 |  189862381 |
| trackingdb   | tr_user_tracknumber_58126_58126      |  38.287780761719 | 26.912246704102 |  65.200027465820 |   50795358 |
| trackingdb   | tr_tracking_special                  |  38.296875000000 | 20.229385375977 |  58.526260375977 |   77730949 |
| trackingdb   | tr_tracking_info_114501_115000       |  47.528518676758 |  1.608001708984 |  49.136520385742 |    2658955 |
| trackingdb   | tr_tracking_info_436501_437000       |  46.463043212891 |  1.561828613281 |  48.024871826172 |    2739380 |
| trackingdb   | tr_tracking_info_58132_58132         |  45.398361206055 |  1.805770874023 |  47.204132080078 |    3146128 |
| trackingdb   | tr_tracking_number_middle_yunexpress |  11.426757812500 | 26.205062866211 |  37.631820678711 |   45145759 |
| trackingdb   | tr_user_track_send_msg_log           |  24.720596313477 | 12.645950317383 |  37.366546630859 |   21817037 |
| trackingdb   | tr_tracking_number_middle_fedex      |  10.312500000000 | 22.482406616211 |  32.794906616211 |   40763463 |
| trackingdb   | tr_user_phone_email_title            |  11.456039428711 | 20.914916992188 |  32.370956420898 |  167938260 |
| trackingdb   | tr_user_tracknumber_218001_218500    |  18.956680297852 | 11.852081298828 |  30.808761596680 |   26002585 |
| trackingdb   | tr_tracking_info_easypost            |  24.297958374023 |  2.829803466797 |  27.127761840820 |    4990984 |
+--------------+--------------------------------------+------------------+-----------------+------------------+------------+

+-----------------------------------------------------------+-----------+---------------+
| FILE_NAME                                                 | FIle_size | TOTAL_EXTENTS |
+-----------------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_tracking_info_58126_58126#p#p20250801.ibd | 97.4844G  |         99824 |
| ./trackingdb/tr_tracking_info_58126_58126#p#p20250701.ibd | 81.3906G  |         83344 |
| ./trackingdb/tr_tracking_info_58126_58126#p#p20250901.ibd | 73.6289G  |         75396 |
| ./trackingdb/tr_tracking_info_58126_58126#p#p20250601.ibd | 72.3320G  |         74068 |
| ./trackingdb/tr_tracking_info_58126_58126#p#p20250401.ibd | 60.3828G  |         61832 |
| ./trackingdb/tr_tracking_info_58126_58126#p#p20250501.ibd | 59.8828G  |         61320 |
| ./trackingdb/tr_tracking_info_58126_58126#p#p20250301.ibd | 37.7422G  |         38648 |
| ./trackingdb/tr_tracking_info_58126_58126#p#p_max.ibd     | 24.8750G  |         25472 |
+-----------------------------------------------------------+-----------+---------------+
8 rows in set (0.43 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_tracking_info_218001_218500%' order by TOTAL_EXTENTS DESC limit 50;
+-------------------------------------------------------------+-----------+---------------+
| FILE_NAME                                                   | FIle_size | TOTAL_EXTENTS |
+-------------------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_tracking_info_218001_218500#p#p20250801.ibd | 35.9844G  |         36848 |
| ./trackingdb/tr_tracking_info_218001_218500#p#p20250901.ibd | 25.6484G  |         26264 |
| ./trackingdb/tr_tracking_info_218001_218500#p#p20250701.ibd | 24.6211G  |         25212 |
| ./trackingdb/tr_tracking_info_218001_218500#p#p20250601.ibd | 21.4063G  |         21920 |
| ./trackingdb/tr_tracking_info_218001_218500#p#p20250501.ibd | 19.6289G  |         20100 |
| ./trackingdb/tr_tracking_info_218001_218500#p#p20250401.ibd | 17.6055G  |         18028 |
| ./trackingdb/tr_tracking_info_218001_218500#p#p_max.ibd     | 10.4414G  |         10692 |
| ./trackingdb/tr_tracking_info_218001_218500#p#p20250301.ibd | 9.8711G   |         10108 |
+-------------------------------------------------------------+-----------+---------------+
8 rows in set (0.07 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_express_statistics_bitmap_min%' order by TOTAL_EXTENTS DESC limit 50;
+---------------------------------------------------------------+-----------+---------------+
| FILE_NAME                                                     | FIle_size | TOTAL_EXTENTS |
+---------------------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20250101.ibd | 5.5469G   |          5680 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20250801.ibd | 5.1445G   |          5268 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20250201.ibd | 4.8438G   |          4960 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20250701.ibd | 4.8438G   |          4960 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20250901.ibd | 4.8281G   |          4944 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20241201.ibd | 4.8008G   |          4916 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20250601.ibd | 4.7422G   |          4856 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20230801.ibd | 4.6641G   |          4776 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20250501.ibd | 4.5977G   |          4708 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20250401.ibd | 4.5195G   |          4628 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20241101.ibd | 4.1250G   |          4224 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20250301.ibd | 3.8555G   |          3948 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20240801.ibd | 3.3750G   |          3456 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20240901.ibd | 3.3594G   |          3440 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20240701.ibd | 3.3125G   |          3392 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20241001.ibd | 3.2852G   |          3364 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20240601.ibd | 3.1563G   |          3232 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20240501.ibd | 3.1289G   |          3204 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20240401.ibd | 3.0859G   |          3160 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20240101.ibd | 2.9844G   |          3056 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20240201.ibd | 2.9219G   |          2992 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20231201.ibd | 2.7070G   |          2772 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20240301.ibd | 2.6406G   |          2704 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20231101.ibd | 2.4219G   |          2480 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20230901.ibd | 2.4023G   |          2460 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20231001.ibd | 2.2305G   |          2284 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20230601.ibd | 2.0938G   |          2144 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20230501.ibd | 2.0195G   |          2068 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20230401.ibd | 1.9961G   |          2044 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20230101.ibd | 1.8789G   |          1924 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20230201.ibd | 1.8047G   |          1848 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20230301.ibd | 1.6914G   |          1732 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20220601.ibd | 1.6484G   |          1688 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20221201.ibd | 1.5742G   |          1612 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20221101.ibd | 1.4297G   |          1464 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20220701.ibd | 1.3984G   |          1432 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20220101.ibd | 1.3906G   |          1424 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20220901.ibd | 1.3672G   |          1400 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20220501.ibd | 1.3438G   |          1376 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20220401.ibd | 1.3398G   |          1372 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20221001.ibd | 1.3164G   |          1348 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20220801.ibd | 1.3086G   |          1340 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20211201.ibd | 1.2344G   |          1264 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20220201.ibd | 1.2227G   |          1252 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20211101.ibd | 1.1406G   |          1168 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20201201.ibd | 1.1367G   |          1164 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20201101.ibd | 1.1250G   |          1152 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20211001.ibd | 1.1055G   |          1132 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20210701.ibd | 1.0938G   |          1120 |
| ./trackingdb/tr_express_statistics_bitmap_min#p#p20210801.ibd | 1.0664G   |          1092 |
+---------------------------------------------------------------+-----------+---------------+
50 rows in set (0.07 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_user_cost_deducte_log%' order by TOTAL_EXTENTS DESC limit 50;
+-----------------------------------------------------+-----------+---------------+
| FILE_NAME                                           | FIle_size | TOTAL_EXTENTS |
+-----------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_user_cost_deducte_log#p#p_max.ibd   | 119.2734G |        122136 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202212.ibd | 2.2852G   |          2340 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202211.ibd | 2.0586G   |          2108 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202204.ibd | 1.7773G   |          1820 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202112.ibd | 1.7305G   |          1772 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202210.ibd | 1.6523G   |          1692 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202111.ibd | 1.5078G   |          1544 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202205.ibd | 1.4922G   |          1528 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202203.ibd | 1.4570G   |          1492 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202208.ibd | 1.3984G   |          1432 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202201.ibd | 1.3906G   |          1424 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202206.ibd | 1.3477G   |          1380 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202209.ibd | 1.3047G   |          1336 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202207.ibd | 1.2813G   |          1312 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202202.ibd | 1.2695G   |          1300 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202110.ibd | 1.2539G   |          1284 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202106.ibd | 1.1289G   |          1156 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202108.ibd | 1.0938G   |          1120 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202109.ibd | 1.0352G   |          1060 |
| ./trackingdb/tr_user_cost_deducte_log#p#p202107.ibd | 1.0195G   |          1044 |
+-----------------------------------------------------+-----------+---------------+
20 rows in set (0.06 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_trackinfo_effective_for_rule%' order by TOTAL_EXTENTS DESC limit 50;
+--------------------------------------------------+-----------+---------------+
| FILE_NAME                                        | FIle_size | TOTAL_EXTENTS |
+--------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_trackinfo_effective_for_rule.ibd | 112.5898G |        115292 |
+--------------------------------------------------+-----------+---------------+
1 row in set (0.07 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_tracking_info_224501_225000%' order by TOTAL_EXTENTS DESC limit 50;
+-------------------------------------------------------------+-----------+---------------+
| FILE_NAME                                                   | FIle_size | TOTAL_EXTENTS |
+-------------------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_tracking_info_224501_225000#p#p20250901.ibd | 16.8945G  |         17300 |
| ./trackingdb/tr_tracking_info_224501_225000#p#p20250801.ibd | 16.4844G  |         16880 |
| ./trackingdb/tr_tracking_info_224501_225000#p#p20250701.ibd | 15.4102G  |         15780 |
| ./trackingdb/tr_tracking_info_224501_225000#p#p20250601.ibd | 14.6523G  |         15004 |
| ./trackingdb/tr_tracking_info_224501_225000#p#p20250401.ibd | 14.2617G  |         14604 |
| ./trackingdb/tr_tracking_info_224501_225000#p#p20250501.ibd | 13.7148G  |         14044 |
| ./trackingdb/tr_tracking_info_224501_225000#p#p20250301.ibd | 7.8984G   |          8088 |
| ./trackingdb/tr_tracking_info_224501_225000#p#p_max.ibd     | 7.8633G   |          8052 |
+-------------------------------------------------------------+-----------+---------------+
8 rows in set (0.07 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_user_cost_rd_log%' order by TOTAL_EXTENTS DESC limit 50;
+------------------------------------------------+-----------+---------------+
| FILE_NAME                                      | FIle_size | TOTAL_EXTENTS |
+------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_user_cost_rd_log#p#p_max.ibd   | 21.3828G  |         21896 |
| ./trackingdb/tr_user_cost_rd_log#p#p202204.ibd | 8.2852G   |          8484 |
| ./trackingdb/tr_user_cost_rd_log#p#p202208.ibd | 6.5469G   |          6704 |
| ./trackingdb/tr_user_cost_rd_log#p#p202210.ibd | 6.2344G   |          6384 |
| ./trackingdb/tr_user_cost_rd_log#p#p202205.ibd | 6.0898G   |          6236 |
| ./trackingdb/tr_user_cost_rd_log#p#p202207.ibd | 5.8750G   |          6016 |
| ./trackingdb/tr_user_cost_rd_log#p#p202209.ibd | 5.8281G   |          5968 |
| ./trackingdb/tr_user_cost_rd_log#p#p202112.ibd | 4.3555G   |          4460 |
| ./trackingdb/tr_user_cost_rd_log#p#p202206.ibd | 4.2305G   |          4332 |
| ./trackingdb/tr_user_cost_rd_log#p#p202106.ibd | 3.4961G   |          3580 |
| ./trackingdb/tr_user_cost_rd_log#p#p202107.ibd | 2.0742G   |          2124 |
| ./trackingdb/tr_user_cost_rd_log#p#p202104.ibd | 2.0625G   |          2112 |
| ./trackingdb/tr_user_cost_rd_log#p#p202212.ibd | 2.0117G   |          2060 |
| ./trackingdb/tr_user_cost_rd_log#p#p202111.ibd | 1.6797G   |          1720 |
| ./trackingdb/tr_user_cost_rd_log#p#p202105.ibd | 1.6523G   |          1692 |
| ./trackingdb/tr_user_cost_rd_log#p#p202110.ibd | 1.5859G   |          1624 |
| ./trackingdb/tr_user_cost_rd_log#p#p202201.ibd | 1.5742G   |          1612 |
| ./trackingdb/tr_user_cost_rd_log#p#p202109.ibd | 1.5273G   |          1564 |
| ./trackingdb/tr_user_cost_rd_log#p#p202108.ibd | 1.5234G   |          1560 |
| ./trackingdb/tr_user_cost_rd_log#p#p202103.ibd | 1.3008G   |          1332 |
| ./trackingdb/tr_user_cost_rd_log#p#p202211.ibd | 1.1602G   |          1188 |
| ./trackingdb/tr_user_cost_rd_log#p#p202203.ibd | 1.0859G   |          1112 |
| ./trackingdb/tr_user_cost_rd_log#p#p202202.ibd | 0.9570G   |           980 |
+------------------------------------------------+-----------+---------------+
23 rows in set (0.06 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_tracking_number_middle_ups%' order by TOTAL_EXTENTS DESC limit 50;
+------------------------------------------------+-----------+---------------+
| FILE_NAME                                      | FIle_size | TOTAL_EXTENTS |
+------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_tracking_number_middle_ups.ibd | 94.6953G  |         96968 |
+------------------------------------------------+-----------+---------------+
1 row in set (0.07 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_user_admin_association%' order by TOTAL_EXTENTS DESC limit 50;
+--------------------------------------------------------+-----------+---------------+
| FILE_NAME                                              | FIle_size | TOTAL_EXTENTS |
+--------------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_user_admin_association#p#p20250901.ibd | 3.9961G   |          4092 |
| ./trackingdb/tr_user_admin_association#p#p20241201.ibd | 3.5078G   |          3592 |
| ./trackingdb/tr_user_admin_association#p#p20250801.ibd | 3.4883G   |          3572 |
| ./trackingdb/tr_user_admin_association#p#p20250101.ibd | 3.4609G   |          3544 |
| ./trackingdb/tr_user_admin_association#p#p20250701.ibd | 3.2070G   |          3284 |
| ./trackingdb/tr_user_admin_association#p#p20250601.ibd | 3.1484G   |          3224 |
| ./trackingdb/tr_user_admin_association#p#p20250501.ibd | 2.7305G   |          2796 |
| ./trackingdb/tr_user_admin_association#p#p20250401.ibd | 2.5820G   |          2644 |
| ./trackingdb/tr_user_admin_association#p#p20250201.ibd | 2.5664G   |          2628 |
| ./trackingdb/tr_user_admin_association#p#p20240101.ibd | 2.3281G   |          2384 |
| ./trackingdb/tr_user_admin_association#p#p20241101.ibd | 2.3203G   |          2376 |
| ./trackingdb/tr_user_admin_association#p#p20250301.ibd | 2.2773G   |          2332 |
| ./trackingdb/tr_user_admin_association#p#p20240901.ibd | 2.0039G   |          2052 |
| ./trackingdb/tr_user_admin_association#p#p20241001.ibd | 1.9766G   |          2024 |
| ./trackingdb/tr_user_admin_association#p#p20240801.ibd | 1.9023G   |          1948 |
| ./trackingdb/tr_user_admin_association#p#p20230801.ibd | 1.8789G   |          1924 |
| ./trackingdb/tr_user_admin_association#p#p20231201.ibd | 1.8750G   |          1920 |
| ./trackingdb/tr_user_admin_association#p#p20240701.ibd | 1.7500G   |          1792 |
| ./trackingdb/tr_user_admin_association#p#p20240601.ibd | 1.7422G   |          1784 |
| ./trackingdb/tr_user_admin_association#p#p20240201.ibd | 1.6797G   |          1720 |
| ./trackingdb/tr_user_admin_association#p#p20240401.ibd | 1.5703G   |          1608 |
| ./trackingdb/tr_user_admin_association#p#p20240501.ibd | 1.5117G   |          1548 |
| ./trackingdb/tr_user_admin_association#p#p_max.ibd     | 1.4922G   |          1528 |
| ./trackingdb/tr_user_admin_association#p#p20240301.ibd | 1.4375G   |          1472 |
| ./trackingdb/tr_user_admin_association#p#p20231101.ibd | 1.2539G   |          1284 |
| ./trackingdb/tr_user_admin_association#p#p20220101.ibd | 1.1055G   |          1132 |
| ./trackingdb/tr_user_admin_association#p#p20230401.ibd | 1.0898G   |          1116 |
| ./trackingdb/tr_user_admin_association#p#p20230101.ibd | 1.0898G   |          1116 |
| ./trackingdb/tr_user_admin_association#p#p20230901.ibd | 1.0234G   |          1048 |
| ./trackingdb/tr_user_admin_association#p#p20231001.ibd | 0.9688G   |           992 |
| ./trackingdb/tr_user_admin_association#p#p20221201.ibd | 0.9258G   |           948 |
| ./trackingdb/tr_user_admin_association#p#p20230601.ibd | 0.8984G   |           920 |
| ./trackingdb/tr_user_admin_association#p#p20221101.ibd | 0.8789G   |           900 |
| ./trackingdb/tr_user_admin_association#p#p20230501.ibd | 0.8750G   |           896 |
| ./trackingdb/tr_user_admin_association#p#p20230301.ibd | 0.7969G   |           816 |
| ./trackingdb/tr_user_admin_association#p#p20230201.ibd | 0.6875G   |           704 |
| ./trackingdb/tr_user_admin_association#p#p20220901.ibd | 0.6641G   |           680 |
| ./trackingdb/tr_user_admin_association#p#p20221001.ibd | 0.5742G   |           588 |
| ./trackingdb/tr_user_admin_association#p#p20220701.ibd | 0.5156G   |           528 |
| ./trackingdb/tr_user_admin_association#p#p20220201.ibd | 0.5156G   |           528 |
| ./trackingdb/tr_user_admin_association#p#p20220801.ibd | 0.5117G   |           524 |
| ./trackingdb/tr_user_admin_association#p#p20220401.ibd | 0.4961G   |           508 |
| ./trackingdb/tr_user_admin_association#p#p20220601.ibd | 0.4883G   |           500 |
| ./trackingdb/tr_user_admin_association#p#p20220501.ibd | 0.4766G   |           488 |
| ./trackingdb/tr_user_admin_association#p#p20220301.ibd | 0.4453G   |           456 |
| ./trackingdb/tr_user_admin_association#p#p20211201.ibd | 0.3828G   |           392 |
+--------------------------------------------------------+-----------+---------------+
46 rows in set (0.06 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_user_tracknumber_58126_58126%' order by TOTAL_EXTENTS DESC limit 50;
+--------------------------------------------------+-----------+---------------+
| FILE_NAME                                        | FIle_size | TOTAL_EXTENTS |
+--------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_user_tracknumber_58126_58126.ibd | 66.9375G  |         68544 |
+--------------------------------------------------+-----------+---------------+
1 row in set (0.07 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_tracking_special%' order by TOTAL_EXTENTS DESC limit 50;
+--------------------------------------+-----------+---------------+
| FILE_NAME                            | FIle_size | TOTAL_EXTENTS |
+--------------------------------------+-----------+---------------+
| ./trackingdb/tr_tracking_special.ibd | 69.5352G  |         71204 |
+--------------------------------------+-----------+---------------+
1 row in set (0.06 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_tracking_info_114501_115000%' order by TOTAL_EXTENTS DESC limit 50;
+-------------------------------------------------------------+-----------+---------------+
| FILE_NAME                                                   | FIle_size | TOTAL_EXTENTS |
+-------------------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_tracking_info_114501_115000#p#p20250401.ibd | 14.6836G  |         15036 |
| ./trackingdb/tr_tracking_info_114501_115000#p#p20250201.ibd | 8.4297G   |          8632 |
| ./trackingdb/tr_tracking_info_114501_115000#p#p20250301.ibd | 8.2344G   |          8432 |
| ./trackingdb/tr_tracking_info_114501_115000#p#p20250501.ibd | 4.1484G   |          4248 |
| ./trackingdb/tr_tracking_info_114501_115000#p#p20250601.ibd | 4.1211G   |          4220 |
| ./trackingdb/tr_tracking_info_114501_115000#p#p20250701.ibd | 4.0039G   |          4100 |
| ./trackingdb/tr_tracking_info_114501_115000#p#p20250801.ibd | 3.2031G   |          3280 |
| ./trackingdb/tr_tracking_info_114501_115000#p#p20250901.ibd | 2.3281G   |          2384 |
| ./trackingdb/tr_tracking_info_114501_115000#p#p20250101.ibd | 1.5391G   |          1576 |
| ./trackingdb/tr_tracking_info_114501_115000#p#p_max.ibd     | 0.7188G   |           736 |
+-------------------------------------------------------------+-----------+---------------+
10 rows in set (0.07 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_tracking_info_436501_437000%' order by TOTAL_EXTENTS DESC limit 50;
+-------------------------------------------------------------+-----------+---------------+
| FILE_NAME                                                   | FIle_size | TOTAL_EXTENTS |
+-------------------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_tracking_info_436501_437000#p#p20250601.ibd | 12.7461G  |         13052 |
| ./trackingdb/tr_tracking_info_436501_437000#p#p20250701.ibd | 11.2891G  |         11560 |
| ./trackingdb/tr_tracking_info_436501_437000#p#p20250801.ibd | 8.9336G   |          9148 |
| ./trackingdb/tr_tracking_info_436501_437000#p#p20250501.ibd | 7.9727G   |          8164 |
| ./trackingdb/tr_tracking_info_436501_437000#p#p20250901.ibd | 7.5742G   |          7756 |
| ./trackingdb/tr_tracking_info_436501_437000#p#p_max.ibd     | 2.2773G   |          2332 |
| ./trackingdb/tr_tracking_info_436501_437000#p#p20250401.ibd | 0.0088G   |             9 |
+-------------------------------------------------------------+-----------+---------------+
7 rows in set (0.07 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_tracking_info_58132_58132%' order by TOTAL_EXTENTS DESC limit 50;
+-----------------------------------------------------------+-----------+---------------+
| FILE_NAME                                                 | FIle_size | TOTAL_EXTENTS |
+-----------------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_tracking_info_58132_58132#p#p20250601.ibd | 9.5898G   |          9820 |
| ./trackingdb/tr_tracking_info_58132_58132#p#p20250701.ibd | 9.0898G   |          9308 |
| ./trackingdb/tr_tracking_info_58132_58132#p#p20250401.ibd | 8.9219G   |          9136 |
| ./trackingdb/tr_tracking_info_58132_58132#p#p20250801.ibd | 7.7266G   |          7912 |
| ./trackingdb/tr_tracking_info_58132_58132#p#p20250501.ibd | 7.5273G   |          7708 |
| ./trackingdb/tr_tracking_info_58132_58132#p#p20250901.ibd | 6.1445G   |          6292 |
| ./trackingdb/tr_tracking_info_58132_58132#p#p20250301.ibd | 5.4453G   |          5576 |
| ./trackingdb/tr_tracking_info_58132_58132#p#p_max.ibd     | 2.2227G   |          2276 |
+-----------------------------------------------------------+-----------+---------------+
8 rows in set (0.07 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_tracking_number_middle_yunexpress%' order by TOTAL_EXTENTS DESC limit 50;
+-------------------------------------------------------+-----------+---------------+
| FILE_NAME                                             | FIle_size | TOTAL_EXTENTS |
+-------------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_tracking_number_middle_yunexpress.ibd | 41.9883G  |         42996 |
+-------------------------------------------------------+-----------+---------------+
1 row in set (0.06 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_user_track_send_msg_log%' order by TOTAL_EXTENTS DESC limit 50;
+---------------------------------------------------------+-----------+---------------+
| FILE_NAME                                               | FIle_size | TOTAL_EXTENTS |
+---------------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_user_track_send_msg_log#p#p20210601.ibd | 1.8203G   |          1864 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20210201.ibd | 1.5234G   |          1560 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20210701.ibd | 1.4922G   |          1528 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20210501.ibd | 1.4492G   |          1484 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20210401.ibd | 1.4414G   |          1476 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20220101.ibd | 1.4297G   |          1464 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20210801.ibd | 1.2852G   |          1316 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20210901.ibd | 1.2031G   |          1232 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20211001.ibd | 1.1797G   |          1208 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20211101.ibd | 1.0859G   |          1112 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20220201.ibd | 1.0703G   |          1096 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20211201.ibd | 0.9727G   |           996 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20230801.ibd | 0.9570G   |           980 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20210301.ibd | 0.9375G   |           960 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20230101.ibd | 0.8555G   |           876 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20220301.ibd | 0.8477G   |           868 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20220401.ibd | 0.7969G   |           816 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20250701.ibd | 0.7148G   |           732 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20221201.ibd | 0.7070G   |           724 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20250601.ibd | 0.6680G   |           684 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20220701.ibd | 0.6445G   |           660 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20240101.ibd | 0.6445G   |           660 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20220601.ibd | 0.6328G   |           648 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20221001.ibd | 0.6133G   |           628 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20220501.ibd | 0.6094G   |           624 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20231201.ibd | 0.5977G   |           612 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20250801.ibd | 0.5938G   |           608 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20220901.ibd | 0.5898G   |           604 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20250901.ibd | 0.5898G   |           604 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20250501.ibd | 0.5703G   |           584 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20231101.ibd | 0.5508G   |           564 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20230601.ibd | 0.5313G   |           544 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20220801.ibd | 0.5234G   |           536 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20230201.ibd | 0.5156G   |           528 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20230401.ibd | 0.5078G   |           520 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20250401.ibd | 0.4922G   |           504 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20221101.ibd | 0.4883G   |           500 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20231001.ibd | 0.4844G   |           496 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20230901.ibd | 0.4805G   |           492 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20230301.ibd | 0.4531G   |           464 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20250101.ibd | 0.4492G   |           460 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20240601.ibd | 0.4453G   |           456 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20230501.ibd | 0.4375G   |           448 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20240201.ibd | 0.4258G   |           436 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20240401.ibd | 0.4180G   |           428 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20240901.ibd | 0.4102G   |           420 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20240701.ibd | 0.4063G   |           416 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20240501.ibd | 0.4023G   |           412 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20250201.ibd | 0.3906G   |           400 |
| ./trackingdb/tr_user_track_send_msg_log#p#p20240301.ibd | 0.3633G   |           372 |
+---------------------------------------------------------+-----------+---------------+
50 rows in set (0.06 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_tracking_number_middle_fedex%' order by TOTAL_EXTENTS DESC limit 50;
+--------------------------------------------------+-----------+---------------+
| FILE_NAME                                        | FIle_size | TOTAL_EXTENTS |
+--------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_tracking_number_middle_fedex.ibd | 37.0195G  |         37908 |
+--------------------------------------------------+-----------+---------------+
1 row in set (0.07 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_user_phone_email_title%' order by TOTAL_EXTENTS DESC limit 50;
+--------------------------------------------------------+-----------+---------------+
| FILE_NAME                                              | FIle_size | TOTAL_EXTENTS |
+--------------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_user_phone_email_title#p#p_max.ibd     | 18.9375G  |         19392 |
| ./trackingdb/tr_user_phone_email_title#p#p20211201.ibd | 1.3008G   |          1332 |
| ./trackingdb/tr_user_phone_email_title#p#p20220101.ibd | 1.2070G   |          1236 |
| ./trackingdb/tr_user_phone_email_title#p#p20210501.ibd | 1.1445G   |          1172 |
| ./trackingdb/tr_user_phone_email_title#p#p20210601.ibd | 1.1289G   |          1156 |
| ./trackingdb/tr_user_phone_email_title#p#p20210201.ibd | 1.0586G   |          1084 |
| ./trackingdb/tr_user_phone_email_title#p#p20210401.ibd | 1.0547G   |          1080 |
| ./trackingdb/tr_user_phone_email_title#p#p20211001.ibd | 1.0391G   |          1064 |
| ./trackingdb/tr_user_phone_email_title#p#p20210801.ibd | 1.0352G   |          1060 |
| ./trackingdb/tr_user_phone_email_title#p#p20210901.ibd | 1.0313G   |          1056 |
| ./trackingdb/tr_user_phone_email_title#p#p20211101.ibd | 0.9922G   |          1016 |
| ./trackingdb/tr_user_phone_email_title#p#p20210701.ibd | 0.9297G   |           952 |
| ./trackingdb/tr_user_phone_email_title#p#p20210301.ibd | 0.8750G   |           896 |
| ./trackingdb/tr_user_phone_email_title#p#p20220201.ibd | 0.8750G   |           896 |
| ./trackingdb/tr_user_phone_email_title#p#p20220301.ibd | 0.5547G   |           568 |
| ./trackingdb/tr_user_phone_email_title#p#p20220501.ibd | 0.4961G   |           508 |
| ./trackingdb/tr_user_phone_email_title#p#p20220401.ibd | 0.4766G   |           488 |
| ./trackingdb/tr_user_phone_email_title#p#p20210101.ibd | 0.0244G   |            25 |
+--------------------------------------------------------+-----------+---------------+
18 rows in set (0.06 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_user_tracknumber_218001_218500%' order by TOTAL_EXTENTS DESC limit 50;
+---------------------------------------------------------+-----------+---------------+
| FILE_NAME                                               | FIle_size | TOTAL_EXTENTS |
+---------------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_user_tracknumber_218001_218500#p#p9.ibd | 31.4180G  |         32172 |
| ./trackingdb/tr_user_tracknumber_218001_218500#p#p5.ibd | 0.0107G   |            11 |
+---------------------------------------------------------+-----------+---------------+
2 rows in set (0.07 sec)

mysql> SELECT file_name, concat(TOTAL_EXTENTS/1024,'G') as 'FIle_size', TOTAL_EXTENTS FROM INFORMATION_SCHEMA.FILES where TOTAL_EXTENTS <> 0 and file_name like '%tr_tracking_info_easypost%' order by TOTAL_EXTENTS DESC limit 50;
+--------------------------------------------------------+-----------+---------------+
| FILE_NAME                                              | FIle_size | TOTAL_EXTENTS |
+--------------------------------------------------------+-----------+---------------+
| ./trackingdb/tr_tracking_info_easypost#p#p20250401.ibd | 12.3164G  |         12612 |
| ./trackingdb/tr_tracking_info_easypost#p#p20250501.ibd | 11.6797G  |         11960 |
| ./trackingdb/tr_tracking_info_easypost#p#p20250301.ibd | 6.5859G   |          6744 |
| ./trackingdb/tr_tracking_info_easypost#p#p20250601.ibd | 5.1523G   |          5276 |
+--------------------------------------------------------+-----------+---------------+
4 rows in set (0.06 sec)

```

### 解决方案

#### 短期

```sql

-- tr_trackinfo_effective_for_rule 进行备份清理
-- 从以下分析得到数据是2024年8月30日跑的用于单号规则优化的有效单号（大概范围是6、7、8月份3个月）

mysql> select create_time,from_unixtime(create_time) from tr_trackinfo_effective_for_rule limit 1 \G
*************************** 1. row ***************************
               create_time: 1725015304
from_unixtime(create_time): 2024-08-30 10:55:04
1 row in set (0.00 sec)

mysql> select create_time,from_unixtime(create_time) from tr_trackinfo_effective_for_rule order by id desc limit 1 \G
*************************** 1. row ***************************
               create_time: 1725086769
from_unixtime(create_time): 2024-08-31 06:46:09
1 row in set (0.01 sec)

mysql> select * from tr_trackinfo_effective_for_rule order by id desc limit 1 \G
*************************** 1. row ***************************
                      id: 16362557
            track_number: 1ZA222W76824601949
                 courier: ups
                  userid: 0
        tracking_info_id: 452587
            target_table: tr_tracking_info_98501_99000
first_tracking_info_time: 1718983586
        info_create_time: 1719305626
        info_update_time: 1719416723
             create_time: 1725086769
             update_time: 0
               is_delete: 0
             origin_info: {"en":{"destinationcountry":"CZ","destination_state":"","destination_city":"FRENSTAT POD RADHOSTEM","countryname":"PL","origin_state":"","origin_city":"LUKOW","ScheduledDeliveryDate":"2024-06-26","Scheduled_Address":"","SignedForByName":"RANDUS","product_type":"","service_code":"UPS Standard\u00ae","pieces":1,"weight":"1.00 KGS","weight_kg":1,"dimension":"30.00x10.00x6.00 CM","destination_track_number":"","trackinfo":[{"StatusDescription":"DELIVERED","Date":"2024-06-26 14:30:10","Details":"FRENSTAT POD RADHOSTEM, CZ","CountryIso2":"CZ","City":"FRENSTAT POD RADHOSTEM","RawStatus":"011","checkpoint_status":"delivered","substatus":"delivered001"},{"StatusDescription":"Import Scan","Date":"2024-06-25 22:46:47","Details":"Brno, Czech Republic","CountryIso2":"CZ","City":"Brno","RawStatus":"005","checkpoint_status":"transit","substatus":"transit005"},{"StatusDescription":"Arrived at Facility","Date":"2024-06-24 23:02:00","Details":"Wolka Kosowska, Poland","CountryIso2":"PL","City":"Wolka Kosowska","RawStatus":"005","checkpoint_status":"transit","substatus":"transit001"},{"StatusDescription":"Departed from Facility","Date":"2024-06-24 22:24:00","Details":"Warszawa, Poland","CountryIso2":"PL","City":"Warszawa","RawStatus":"005","checkpoint_status":"transit","substatus":"transit001"},{"StatusDescription":"Arrived at Facility","Date":"2024-06-24 19:17:28","Details":"Warszawa, Poland","CountryIso2":"PL","City":"Warszawa","RawStatus":"005","checkpoint_status":"transit","substatus":"transit001"},{"StatusDescription":"Pickup Scan","Date":"2024-06-24 10:48:37","Details":"Warszawa, Poland","CountryIso2":"PL","City":"Warszawa","RawStatus":"160","checkpoint_status":"transit","substatus":"transit001","ItemNode":"ItemReceived"},{"StatusDescription":"Shipper created a label, UPS has not received the package yet.","Date":"2024-06-21 15:26:26","Details":"Poland","CountryIso2":"PL","RawStatus":"003","substatus_num":21,"substatus":"notfound001","checkpoint_status":"transit"}],"tracklang":"en","stausDataNum":4,"statusNum":4,"statusInfo":"DELIVERED,FRENSTAT POD RADHOSTEM, CZ,2024-06-26 14:30:10","lastUpdateTime":"2024-06-26 14:30:10","firstUpdateTime":"2024-06-21 15:26:26","itemTimeLength":3,"stayTimeLength":1,"CustomsClearance":"2024-06-25 22:46:47","ItemReceived":"2024-06-24 10:48:37","substatus":"delivered001","substatusTime":1719383410,"lang":9,"fromSearchSpendTime":257.15684890747,"destinationcountryname":"CZ","support":1,"infoState":2,"OriginPhone":"+1 800 742 5877","phonenum":"+1 800 742 5877","companyName":"UPS","weblink":"https:\/\/www.ups.com\/","email":"totaltrack.gb-eng@ups.com","companyCode":"ups"}}
        destination_info: 
            track_status: 4
1 row in set (0.00 sec)

mysql> select * from tr_tracknumber_effective_for_rule order by id desc limit 1 \G
*************************** 1. row ***************************
                      id: 22104338
            track_number: YS680034850GR
                 courier: elta-courier-gr
                  userid: 0
        tracking_info_id: 560241
            target_table: tr_tracking_info_99001_99500
first_tracking_info_time: 1748426040
             create_time: 1755134454
             update_time: 0
               is_delete: 0
1 row in set (0.01 sec)

mysql> select max(create_time),from_unixtime(create_time) from tr_trackinfo_effective_for_rule limit 1 \G
*************************** 1. row ***************************
          max(create_time): 1725086769
from_unixtime(create_time): 2024-08-30 10:55:04
1 row in set (3 min 20.13 sec)

mysql> show create table tr_trackinfo_effective_for_rule\G*************************** 1. row ***************************
       Table: tr_trackinfo_effective_for_rule
Create Table: CREATE TABLE `tr_trackinfo_effective_for_rule` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `track_number` char(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `courier` char(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL COMMENT '快递公司',
  `userid` int unsigned NOT NULL DEFAULT '0' COMMENT '当前日期',
  `tracking_info_id` int unsigned NOT NULL COMMENT '关联tr_tracking_info表中的id',
  `target_table` char(36) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci NOT NULL COMMENT '获取数据的目标表，tr_tracking_info系列',
  `first_tracking_info_time` int unsigned NOT NULL COMMENT '第一条物流信息的时间，作为更新顺序参考',
  `info_create_time` int unsigned NOT NULL COMMENT '创建时间（时间戳）',
  `info_update_time` int unsigned NOT NULL COMMENT 'info表更新时间（时间戳）',
  `create_time` int unsigned NOT NULL COMMENT '创建时间',
  `update_time` int unsigned NOT NULL DEFAULT '0' COMMENT '修改时间',
  `is_delete` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '是否删除，1为已经删除',
  `origin_info` text CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci COMMENT '发件国信息',
  `destination_info` text CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci COMMENT '收件国信息',
  `track_status` tinyint DEFAULT NULL COMMENT '最新状态',
  PRIMARY KEY (`id`),
  UNIQUE KEY `track_number.courier` (`track_number`,`courier`),
  KEY `c` (`courier`)
) ENGINE=InnoDB AUTO_INCREMENT=16362558 DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci ROW_FORMAT=DYNAMIC COMMENT='各快递有效快递单号，单号规则用'
1 row in set (0.01 sec)

mysql> select create_time,from_unixtime(create_time) from first_tracking_info_time order by id desc limit 1 \G
mysql> select create_time,from_unixtime(create_time),from_unixtime(first_tracking_info_time) from tr_trackinfo_effective_for_rule order by id desc limit 1 \G
*************************** 1. row ***************************
                            create_time: 1725086769
             from_unixtime(create_time): 2024-08-31 06:46:09
from_unixtime(first_tracking_info_time): 2024-06-21 15:26:26
1 row in set (0.00 sec)

mysql> select create_time,from_unixtime(create_time),from_unixtime(first_tracking_info_time) from tr_trackinfo_effective_for_rule order by id limit 1 \G
*************************** 1. row ***************************
                            create_time: 1725015304
             from_unixtime(create_time): 2024-08-30 10:55:04
from_unixtime(first_tracking_info_time): 2024-05-30 16:58:10
1 row in set (0.01 sec)

```

- 手动释放磁盘空间
	- tr_trackinfo_effective_for_rule
		- 备份（阿里云有数据，从阿里云备份）
			- 服务器 ： 在数据库备份-tm
			- msqldump
				- 测试
					- date;msqldump tr_trackinfo_effective_for_rule -w "id = 16362557 "> tr_trackinfo_effective_for_rule.sql;date;
					- date && msqldump tr_trackinfo_effective_for_rule -w "id > 16352557 "> tr_trackinfo_effective_for_rule.sql && date && ll -h tr_trackinfo_effective_for_rule.sql && zip tr_trackinfo_effective_for_rule.sql.zip.20240530.20240831.created_in_20250830_20250831 tr_trackinfo_effective_for_rule.sql && ll -h tr_trackinfo_effective_for_rule.sql.zip.20240530.20240831.created_in_20250830_20250831 && rm -f tr_trackinfo_effective_for_rule.sql && date
					- echo "date" && date && echo "msqldump tr_trackinfo_effective_for_rule -w "id > 16352557 "> tr_trackinfo_effective_for_rule.sql" && msqldump tr_trackinfo_effective_for_rule -w "id > 16352557 "> tr_trackinfo_effective_for_rule.sql && echo "date" && date && echo "ll -h tr_trackinfo_effective_for_rule.sql" && ll -h tr_trackinfo_effective_for_rule.sql && echo "zip tr_trackinfo_effective_for_rule.sql.zip.20240530.20240831.created_in_20250830_20250831 tr_trackinfo_effective_for_rule.sql" && zip tr_trackinfo_effective_for_rule.sql.zip.20240530.20240831.created_in_20250830_20250831 tr_trackinfo_effective_for_rule.sql && echo "ll -h tr_trackinfo_effective_for_rule.sql.zip.20240530.20240831.created_in_20250830_20250831" && ll -h tr_trackinfo_effective_for_rule.sql.zip.20240530.20240831.created_in_20250830_20250831 && echo "rm -f tr_trackinfo_effective_for_rule.sql" && rm -f tr_trackinfo_effective_for_rule.sql && echo "dat" && date
				- 正式
					- cd /mnt/bak/trackingdb
					- echo 'echo "date" && date && echo "msqldump tr_trackinfo_effective_for_rule> tr_trackinfo_effective_for_rule.sql" && msqldump tr_trackinfo_effective_for_rule> tr_trackinfo_effective_for_rule.sql && echo "date" && date && echo "ll -h tr_trackinfo_effective_for_rule.sql" && ll -h tr_trackinfo_effective_for_rule.sql && echo "zip tr_trackinfo_effective_for_rule.sql.zip.20240530.20240831.created_in_20250830_20250831 tr_trackinfo_effective_for_rule.sql" && zip tr_trackinfo_effective_for_rule.sql.zip.20240530.20240831.created_in_20250830_20250831 tr_trackinfo_effective_for_rule.sql && echo "ll -h tr_trackinfo_effective_for_rule.sql.zip.20240530.20240831.created_in_20250830_20250831" && ll -h tr_trackinfo_effective_for_rule.sql.zip.20240530.20240831.created_in_20250830_20250831 && echo "rm -f tr_trackinfo_effective_for_rule.sql" && rm -f tr_trackinfo_effective_for_rule.sql && echo "date" && date' >> backup.tr_trackinfo_effective_for_rule.log
					- echo "date" && date && echo "msqldump tr_trackinfo_effective_for_rule> tr_trackinfo_effective_for_rule.sql" && msqldump tr_trackinfo_effective_for_rule> tr_trackinfo_effective_for_rule.sql && echo "date" && date && echo "ll -h tr_trackinfo_effective_for_rule.sql" && ll -h tr_trackinfo_effective_for_rule.sql && echo "zip tr_trackinfo_effective_for_rule.sql.zip.20240530.20240831.created_in_20250830_20250831 tr_trackinfo_effective_for_rule.sql" && zip tr_trackinfo_effective_for_rule.sql.zip.20240530.20240831.created_in_20250830_20250831 tr_trackinfo_effective_for_rule.sql && echo "ll -h tr_trackinfo_effective_for_rule.sql.zip.20240530.20240831.created_in_20250830_20250831" && ll -h tr_trackinfo_effective_for_rule.sql.zip.20240530.20240831.created_in_20250830_20250831 && echo "rm -f tr_trackinfo_effective_for_rule.sql" && rm -f tr_trackinfo_effective_for_rule.sql && echo "date" && date >> backup.tr_trackinfo_effective_for_rule.log
		- 清除
			- truncate table tr_trackinfo_effective_for_rule;

#### 长期

- 定时任务定期释放磁盘空间（以下表是空间占用前20的表）
	- 分区维护（自动创建，最大分区写数据的问题需要处理）
		- 无分区
			- tr_tracking_number_middle_fedex
			- tr_tracking_number_middle_yunexpress
			- tr_tracking_special
			- tr_user_tracknumber_58126_58126
			- tr_tracking_number_middle_ups
			- tr_trackinfo_effective_for_rule
		- 未自动创建
			- tr_tracking_info_easypost
				- 2025年06月开始
			- tr_user_phone_email_title
				- 2022年开始
			- tr_user_cost_rd_log
				- 2022年开始
			- tr_user_cost_deducte_log
				- 2022年开始
		- 有自动创建，但迁云后最大分区有数据，且没清除分区数据
			- tr_tracking_info_*_*
				- tr_tracking_info_58132_58132
				- tr_tracking_info_436501_437000
				- tr_tracking_info_114501_115000
				- tr_tracking_info_224501_225000
				- tr_tracking_info_218001_218500
				- tr_tracking_info_58126_58126
			- tr_user_admin_association
		- 没自动清理数据（都有这个问题，truncate分区虽然快，但会锁表）
			- tr_user_track_send_msg_log
			- tr_express_statistics_bitmap_min
	- 按分区清理数据（按月，或改按天）

#### mysqldump相关补充

咨询ai：

帮忙看下，mysqldump导出的文件，默认一个INSERT里有多少条记录

这个问题要分两部分来看：

##### 1. `mysqldump` 的默认行为

* `mysqldump` **默认是一个 INSERT 只包含一条记录**。

  ```sql
  INSERT INTO `table` VALUES (1,'a','b');
  INSERT INTO `table` VALUES (2,'c','d');
  ```
* 这是最安全、最兼容的方式，任何 SQL 客户端都能顺利执行。

##### 2. 多条记录合并到一个 INSERT 的情况

* 如果你加了参数 `--extended-insert`（mysqldump 默认是开启的），它会把多行合并到一个 `INSERT` 里，例如：

  ```sql
  INSERT INTO `table` VALUES (1,'a','b'),(2,'c','d'),(3,'e','f');
  ```
* 每个 `INSERT` 里到底放多少行，取决于 **`max_allowed_packet`** 设置（客户端/服务端的限制）和行数据大小。

  * 一般情况下，mysqldump 会尽可能多地塞到一个 `INSERT` 语句里，直到接近 `max_allowed_packet` 限制。
  * 所以不是一个固定条数，而是根据 **单条数据大小** 和 **`max_allowed_packet`** 来决定。

---

✅ 总结：

* **不开启 `--extended-insert`**：每个 `INSERT` 只有 **1 条记录**。
* **开启 `--extended-insert`（默认）**：一个 `INSERT` 会包含**尽可能多的记录**，受 `max_allowed_packet` 限制。

要确认你导出的文件里每个 `INSERT` 里大概多少行，可以用下面命令数一下：

```bash
grep -c "^INSERT" dump.sql       # 看有多少个 INSERT 语句
grep "^INSERT" dump.sql | head -1
```

要不要我帮你写个脚本，直接算出 **每个 INSERT 的平均行数**？

