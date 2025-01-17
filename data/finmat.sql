###!cnty_def - table with country definitions
CREATE TABLE IF NOT EXISTS cnty_def
(
    cnty_nm VARCHAR(5) NOT NULL PRIMARY KEY,
    cnty_full_nm VARCHAR(20) NOT NULL
);

###!ccy_def - table with currency definitions
CREATE TABLE IF NOT EXISTS ccy_def
(
    ccy_nm CHAR(3) NOT NULL PRIMARY KEY,
    ccy_full_nm VARCHAR(20),
    cnty_nm VARCHAR(5) REFERENCES cnty_def(cnty_nm)
);

###!ccy_data - table with FX rates
CREATE TABLE IF NOT EXISTS ccy_data
(
    ccy_nm CHAR(3) NOT NULL,
    scn_no INT NOT NULL CHECK (scn_no > 0),
    rate FLOAT NOT NULL CHECK (rate > 0),
    FOREIGN KEY (ccy_nm) REFERENCES ccy_def(ccy_nm),
    UNIQUE (ccy_nm, scn_no)
);

###!load_ccy_data - load FX data
SELECT ccy_nm, scn_no, rate FROM ccy_data;

###!dcm_def - table holding day-count-method definitions
CREATE TABLE IF NOT EXISTS dcm_def
(
    dcm VARCHAR(10) PRIMARY KEY,
    description VARCHAR(100)
);

###!crv_def - table holding curve definitions
CREATE TABLE IF NOT EXISTS crv_def
(
    crv_nm VARCHAR(20) NOT NULL PRIMARY KEY,
    ccy_nm CHAR(3),
    dcm VARCHAR(10),
    crv_type VARCHAR(10) NOT NULL,
    underlying1 VARCHAR(20),
    underlying2 VARCHAR(20),
    FOREIGN KEY (ccy_nm) REFERENCES ccy_def(ccy_nm),
    FOREIGN KEY (dcm) REFERENCES fx_def(dcm),
    UNIQUE (crv_nm, ccy_nm)
);

###!crv_data - create table holding curve data
CREATE TABLE IF NOT EXISTS crv_data
(
    crv_nm VARCHAR(20) NOT NULL,
    scn_no INT NOT NULL CHECK (scn_no > 0),
    tenor INT NOT NULL CHECK (tenor > 0),
    rate FLOAT NOT NULL,
    FOREIGN KEY (crv_nm) REFERENCES crv_def(crv_nm)
    UNIQUE (crv_nm, scn_no, tenor)
);

###!load_all_crv_nms - load list of all curve names
SELECT crv_nm FROM crv_def;

###!load_crv_def - load curve definitions
SELECT
     crv1.crv_nm
    ,COALESCE(crv1.ccy_nm, crv2.ccy_nm) AS ccy_nm
    ,COALESCE(crv1.dcm, crv2.dcm) AS dcm
    ,crv1.crv_type
    ,crv1.underlying1
    ,crv1.underlying2 
FROM
    crv_def AS crv1
    LEFT JOIN crv_def AS crv2 ON crv1.underlying1 = crv2.crv_nm 
WHERE
    crv1.crv_nm = ##crv_nm##;

###!load_base_crv_data - load curve data for a base curve
SELECT scn_no, tenor, rate FROM crv_data WHERE crv_nm = ##crv_nm##;

###!load_compound_crv_data - load curve data for a compound curve
SELECT
    crv1.scn_no,
    crv1.tenor,
    crv1.rate + crv2.rate AS rate 
FROM
    crv_data AS crv1
    INNER JOIN crv_data AS crv2 ON crv1.scn_no = crv2.scn_no AND crv1.tenor = crv2.tenor 
WHERE
    crv1.crv_nm = ##crv_nm1##
    AND crv2.crv_nm = ##crv_nm2##;

###!vol_surf_def - table with volatility surface definitions
CREATE TABLE IF NOT EXISTS vol_surf_def
(
    vol_surf_nm VARCHAR(20) NOT NULL PRIMARY KEY,
    ccy_nm CHAR(3) NOT NULL REFERENCES ccy_data(ccy_nm),
    underlying VARCHAR(20) NOT NULL,
    vol_surf_type VARCHAR(20) NOT NULL CHECK (vol_surf_type = "cap" OR vol_surf_type = "floor" OR vol_surf_type = "swaption" OR vol_surf_type = "equity"),
    comments VARCHAR(100)
);

###!vol_surf_data - table with volatility surfaces
CREATE TABLE IF NOT EXISTS vol_surf_data
(
    vol_surf_nm CHAR(3) NOT NULL,
    scn_no INT NOT NULL CHECK (scn_no > 0),
    tenor FLOAT NOT NULL CHECK (tenor >= 0),
    strike FLOAT NOT NULL,
    volatility FLOAT NOT NULL CHECK (volatility > 0),
    FOREIGN KEY (vol_surf_nm) REFERENCES vol_surf_def(vol_surf_nm),
    UNIQUE (vol_surf_nm, scn_no, tenor, strike)
);

###!load_all_vol_surf_nms - load list of all volatility surfaces
SELECT vol_surf_nm FROM vol_surf_def;

###!load_vol_surf_def - load volatity surface definitions
SELECT vol_surf_nm, ccy_nm, vol_surf_type, underlying FROM vol_surf_def WHERE vol_surf_nm = ##vol_surf_nm##;

###!load_vol_surf_data - load volatity surface data
SELECT scn_no, tenor, strike, volatility FROM vol_surf_data WHERE vol_surf_nm = ##vol_surf_nm##;
    
###!freq_def - table holding frequency definitions
CREATE TABLE IF NOT EXISTS freq_def
(
    freq VARCHAR(5) PRIMARY KEY
)
    
###!bnd_data - table holding bonds definitions
CREATE TABLE IF NOT EXISTS bnd_data
(
    ent_nm VARCHAR(5) NOT NULL,
    parent_id VARCHAR(10) NOT NULL,
    contract_id VARCHAR(10) NOT NULL,
    issuer_id VARCHAR(15),
    ptf VARCHAR(10) NOT NULL,
    account VARCHAR(50),
    isin VARCHAR(15),
    rtg VARCHAR(5),
    comments VARCHAR(256),
    bnd_type VARCHAR(10),
    fix_type VARCHAR(5),
    ccy_nm CHAR(3) NOT NULL,
    nominal FLOAT NOT NULL,
    value_date INT NOT NULL,
    maturity_date INT NOT NULL,
    dcm VARCHAR(10),
    acc_int FLOAT,
    cpn_rate FLOAT,
    first_cpn_date INT,
    cpn_freq VARCHAR(5),
    first_fix_date INT,
    fix_freq VARCHAR(5),
    rate_mult FLOAT,
    rate_add FLOAT,
    first_amort_date INT,
    amort_freq VARCHAR(5),
    amort FLOAT,
    crv_disc VARCHAR(20) NOT NULL,
    crv_fwd VARCHAR(20),
    FOREIGN KEY (ccy_nm) REFERENCES ccy_def(ccy_nm),
    FOREIGN KEY (dcm) REFERENCES dcm_def(dcm),
    FOREIGN KEY (cpn_freq) REFERENCES freq_def(freq),
    FOREIGN KEY (fix_freq) REFERENCES freq_def(freq),
    FOREIGN KEY (amort_freq) REFERENCES freq_def(freq),
    FOREIGN KEY (crv_disc) REFERENCES crv_def(crv_nm),
    UNIQUE (ent_nm, parent_id, contract_id, ptf)
);

###!bnd_npv - table holding risk measures for bonds
CREATE TABLE IF NOT EXISTS bnd_npv
(
    scn_no INT NOT NULL,
    ent_nm VARCHAR(5) NOT NULL,
    parent_id VARCHAR(10) NOT NULL,
    contract_id VARCHAR(10) NOT NULL,
    ptf  VARCHAR(10) NOT NULL,
    acc_int FLOAT NOT NULL,
    npv FLOAT NOT NULL,
    acc_int_ref_ccy FLOAT NOT NULL,
    npv_ref_ccy FLOAT NOT NULL,
    FOREIGN KEY (ent_nm, parent_id, contract_id, ptf) REFERENCES bnd_data(ent_nm, parent_id, contract_id, ptf)
    UNIQUE (scn_no, ent_nm, parent_id, contract_id, ptf)
)

###!ann_data - table holding annuities definitions
CREATE TABLE IF NOT EXISTS ann_data
(
    ent_nm VARCHAR(5) NOT NULL,
    parent_id VARCHAR(10) NOT NULL,
    contract_id VARCHAR(10) NOT NULL,
    issuer_id VARCHAR(15),
    ptf VARCHAR(10) NOT NULL,
    account VARCHAR(50),
    isin VARCHAR(15),
    rtg VARCHAR(5),
    comments VARCHAR(256),
    ann_type VARCHAR(10),
    fix_type VARCHAR(5),
    ccy_nm CHAR(3) NOT NULL,
    nominal FLOAT NOT NULL,
    value_date INT NOT NULL,
    maturity_date INT NOT NULL,
    acc_int FLOAT,
    internal_rate FLOAT,
    first_ann_date INT NOT NULL,
    ann_freq VARCHAR(5),
    first_fix_date INT,
    fix_freq VARCHAR(5),
    rate_mult FLOAT,
    rate_add FLOAT,
    crv_disc VARCHAR(20) NOT NULL,
    crv_fwd VARCHAR(20),
    FOREIGN KEY (ccy_nm) REFERENCES ccy_def(ccy_nm),
    FOREIGN KEY (ann_freq) REFERENCES freq_def(freq),
    FOREIGN KEY (fix_freq) REFERENCES freq_def(freq),
    FOREIGN KEY (crv_disc) REFERENCES crv_def(crv_nm),
    UNIQUE (ent_nm, parent_id, contract_id, ptf)
);

###!ann_npv - table holding risk measures for annuities
CREATE TABLE IF NOT EXISTS ann_npv
(
    scn_no INT NOT NULL,
    ent_nm VARCHAR(5) NOT NULL,
    parent_id VARCHAR(10) NOT NULL,
    contract_id VARCHAR(10) NOT NULL,
    ptf  VARCHAR(10) NOT NULL,
    ext_acc_int FLOAT NOT NULL,
    ext_npv FLOAT NOT NULL,
    int_npv FLOAT NOT NULL,
    ext_acc_int_ref_ccy FLOAT NOT NULL,
    ext_npv_ref_ccy FLOAT NOT NULL,
    int_npv_ref_ccy FLOAT NOT NULL,
    FOREIGN KEY (ent_nm, parent_id, contract_id, ptf) REFERENCES ann_data(ent_nm, parent_id, contract_id, ptf)
    UNIQUE (scn_no, ent_nm, parent_id, contract_id, ptf)
)

###!cap_floor_data - table holding caps / floors definitions
CREATE TABLE IF NOT EXISTS cap_floor_data
(
    ent_nm VARCHAR(5) NOT NULL,
    parent_id VARCHAR(10) NOT NULL,
    contract_id VARCHAR(10) NOT NULL,
    issuer_id VARCHAR(15),
    ptf VARCHAR(10) NOT NULL,
    account VARCHAR(50),
    isin VARCHAR(15),
    rtg VARCHAR(5),
    comments VARCHAR(256),
    cap_floor_type VARCHAR(10),
    fix_type VARCHAR(5),
    ccy_nm CHAR(3) NOT NULL,
    nominal FLOAT NOT NULL,
    value_date INT NOT NULL,
    maturity_date INT NOT NULL,
    dcm VARCHAR(10),
    cap_rate FLOAT,
    cap_vol_surf_nm VARCHAR(20),
    floor_rate FLOAT,
    floor_vol_surf_nm VARCHAR(20),
    first_int_date INT,
    int_freq VARCHAR(5),
    first_fix_date INT,
    fix_freq VARCHAR(5),
    first_amort_date INT,
    amort_freq VARCHAR(5),
    amort FLOAT,
    crv_disc VARCHAR(20) NOT NULL,
    crv_fwd VARCHAR(20),
    FOREIGN KEY (ccy_nm) REFERENCES ccy_def(ccy_nm),
    FOREIGN KEY (dcm) REFERENCES dcm_def(dcm),
    FOREIGN KEY (int_freq) REFERENCES freq_def(freq),
    FOREIGN KEY (fix_freq) REFERENCES freq_def(freq),
    FOREIGN KEY (amort_freq) REFERENCES freq_def(freq),
    FOREIGN KEY (cap_vol_surf_nm) REFERENCES vol_surf_def(vol_surf_nm),
    FOREIGN KEY (floor_vol_surf_nm) REFERENCES vol_surf_def(vol_surf_nm),
    FOREIGN KEY (crv_disc) REFERENCES crv_def(crv_nm),
    FOREIGN KEY (crv_fwd) REFERENCES crv_def(crv_nm),
    UNIQUE (ent_nm, parent_id, contract_id, ptf)
);

###!cap_floor_npv - table holding risk measures for caps / floors
CREATE TABLE IF NOT EXISTS cap_floor_npv
(
    scn_no INT NOT NULL,
    ent_nm VARCHAR(5) NOT NULL,
    parent_id VARCHAR(10) NOT NULL,
    contract_id VARCHAR(10) NOT NULL,
    ptf  VARCHAR(10) NOT NULL,
    cap_npv FLOAT NOT NULL,
    cap_npv_ref_ccy FLOAT NOT NULL,
    floor_npv FLOAT NOT NULL,
    floor_npv_ref_ccy FLOAT NOT NULL,
    tot_npv FLOAT NOT NULL,
    tot_npv_ref_ccy FLOAT NOT NULL,
    FOREIGN KEY (ent_nm, parent_id, contract_id, ptf) REFERENCES cap_floor_data(ent_nm, parent_id, contract_id, ptf)
    UNIQUE (scn_no, ent_nm, parent_id, contract_id, ptf)
)

###!swaption_data - table holding swaption definitions
CREATE TABLE IF NOT EXISTS swaption_data
(
    ent_nm VARCHAR(5) NOT NULL,
    parent_id VARCHAR(10) NOT NULL,
    contract_id VARCHAR(10) NOT NULL,
    issuer_id VARCHAR(15),
    ptf VARCHAR(10) NOT NULL,
    account VARCHAR(50),
    isin VARCHAR(15),
    rtg VARCHAR(5),
    comments VARCHAR(256),
    swaption_type VARCHAR(10),
    ccy_nm CHAR(3) NOT NULL,
    nominal FLOAT NOT NULL,
    value_date INT NOT NULL,
    maturity_date INT NOT NULL,
    dcm VARCHAR(10),
    swaption_rate FLOAT,
    swaption_vol_surf_nm VARCHAR(20),
    fix_freq VARCHAR(5),
    first_amort_date INT,
    amort_freq VARCHAR(5),
    amort FLOAT,
    crv_disc VARCHAR(20) NOT NULL,
    crv_fwd VARCHAR(20),
    FOREIGN KEY (ccy_nm) REFERENCES ccy_def(ccy_nm),
    FOREIGN KEY (dcm) REFERENCES dcm_def(dcm),
    FOREIGN KEY (fix_freq) REFERENCES freq_def(freq),
    FOREIGN KEY (amort_freq) REFERENCES freq_def(freq),
    FOREIGN KEY (swaption_vol_surf_nm) REFERENCES vol_surf_def(vol_surf_nm),
    FOREIGN KEY (crv_disc) REFERENCES crv_def(crv_nm),
    FOREIGN KEY (crv_fwd) REFERENCES crv_def(crv_nm),
    UNIQUE (ent_nm, parent_id, contract_id, ptf)
);

###!swaption_npv - table holding risk measures for swaptions
CREATE TABLE IF NOT EXISTS swaption_npv
(
    scn_no INT NOT NULL,
    ent_nm VARCHAR(5) NOT NULL,
    parent_id VARCHAR(10) NOT NULL,
    contract_id VARCHAR(10) NOT NULL,
    ptf  VARCHAR(10) NOT NULL,
    npv FLOAT NOT NULL,
    npv_ref_ccy FLOAT NOT NULL,
    FOREIGN KEY (ent_nm, parent_id, contract_id, ptf) REFERENCES cap_floor_data(ent_nm, parent_id, contract_id, ptf)
    UNIQUE (scn_no, ent_nm, parent_id, contract_id, ptf)
)

###!

