#include <string>
#include "lib_dataframe.h"
#include "lib_sqlite.h"
#include "fin_vol_surf.h"

int main()
{
    // variables
    const char * db_file_nm = "data/finmat.db";
    std::string sql_file_nm = "data/finmat.sql";
    std::string cnty_def = "data/cnty_def.csv";
    std::string ccy_def = "data/ccy_def.csv";
    std::string vol_surf_def = "data/vol_surf_def.csv";
    std::string vol_surf_data = "data/vol_surf_data.csv";
    std::string sql;
    myDataFrame * rslt = new myDataFrame();
    std::string sep = ",";
    bool quotes = false;
    bool read_only;
    int wait_max_seconds = 10;
    bool delete_old_data = false;

    // create SQLite object and open connection to SQLite database file in read-write mode
    read_only = false;
    mySQLite db(db_file_nm, read_only, wait_max_seconds);

    // create tables in SQLite database file if they do not exist
    sql = read_sql(sql_file_nm, "cnty_def");
    db.exec(sql);

    sql = read_sql(sql_file_nm, "ccy_def");
    db.exec(sql);

    sql = read_sql(sql_file_nm, "vol_surf_def");
    db.exec(sql);

    sql = read_sql(sql_file_nm, "vol_surf_data");
    db.exec(sql);

    // delete old content in the tables
    db.exec("DELETE FROM cnty_def;");
    db.exec("DELETE FROM ccy_def;");
    db.exec("DELETE FROM vol_surf_def;");
    db.exec("DELETE FROM vol_surf_data;");

    // create dataframes from .csv files and store them into database
    rslt->read(cnty_def, sep, quotes);
    db.upload_tbl(*rslt, "cnty_def", delete_old_data);
    rslt->clear();

    rslt->read(ccy_def, sep, quotes);
    db.upload_tbl(*rslt, "ccy_def", delete_old_data);
    rslt->clear();
    
    rslt->read(vol_surf_def, sep, quotes);
    db.upload_tbl(*rslt, "vol_surf_def", delete_old_data);
    rslt->clear();
   
    rslt->read(vol_surf_data, sep, quotes);
    db.upload_tbl(*rslt, "vol_surf_data", delete_old_data);
    rslt->clear();

    // vacuum SQLite database file to avoid its excessive growth
    db.vacuum();

    // load all volatility surfaces
    myVolSurfaces vol_surfs = myVolSurfaces(db, sql_file_nm);

    // close connection to SQLite database file
    db.close();

    // interpolate volatility
    std::string vol_surf_nm = "CAP_VOL_EUR";
    int scn_no = 1;
    std::vector<double> maturities = {0.572063, 1.07397, 9.07945, 9.57808};
    std::vector<double> strikes = {0.02, 0.02, 0.02, 0.02};
    std::vector<double> volatilities = vol_surfs.get_vols(vol_surf_nm, scn_no, maturities, strikes);

    for (int idx = 0; idx < maturities.size(); idx++)
    {
        std::cout << "maturity: " + std::to_string(maturities[idx]) + ", strike: " + std::to_string(strikes[idx]) + " -> volatility: " + std::to_string(volatilities[idx]) << std::endl;
    }

    // everything OK
    return 0;
}