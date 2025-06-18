import streamlit as st
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait, Select
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
from bs4 import BeautifulSoup
import pandas as pd
import re
import time

def setup_webdriver():
    service = Service(ChromeDriverManager().install())
    options = webdriver.ChromeOptions()
    options.add_argument('--headless=new')  # UI 없이 실행 (필요시 주석 해제)
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    driver = webdriver.Chrome(service=service, options=options)
    return driver

def navigate_to_search_page(driver):
    driver.get("https://www.courtauction.go.kr/")
    driver.switch_to.frame("indexFrame")
    wait = WebDriverWait(driver, 10)
    search_button = wait.until(EC.element_to_be_clickable((By.XPATH, "//div[@id='qk_srch_link_1']/a")))
    search_button.click()

def set_search_criteria(driver, input_data, building_codes):
    Select(driver.find_element(By.ID, 'idJiwonNm')).select_by_value(input_data['jiwon'])
    Select(driver.find_element(By.NAME, 'lclsUtilCd')).select_by_value("0000802")
    Select(driver.find_element(By.NAME, 'mclsUtilCd')).select_by_value("000080201")
    Select(driver.find_element(By.NAME, 'sclsUtilCd')).select_by_value(building_codes[input_data['building']])
    driver.find_element(By.NAME, 'termStartDt').clear()
    driver.find_element(By.NAME, 'termStartDt').send_keys(input_data['start_date'])
    driver.find_element(By.NAME, 'termEndDt').clear()
    driver.find_element(By.NAME, 'termEndDt').send_keys(input_data['end_date'])
    driver.find_element(By.XPATH, '//*[@id="contents"]/form/div[2]/a[1]/img').click()
    time.sleep(2)

def extract_table_data(driver):
    soup = BeautifulSoup(driver.page_source, 'html.parser')
    table = soup.find('table', attrs={'class': 'Ltbl_list'})
    rows = []
    if table:
        for tr in table.find_all('tr')[1:]:
            tds = [td.get_text(strip=True) for td in tr.find_all('td')]
            if tds:
                rows.append(tds)
    return pd.DataFrame(rows)

def main(input_data, building_codes):
    driver = setup_webdriver()
    try:
        navigate_to_search_page(driver)
        set_search_criteria(driver, input_data, building_codes)
        df = extract_table_data(driver)
    finally:
        driver.quit()
    return df

# Streamlit UI
st.title('법원 경매 물건 검색기')

with st.form(key='search_form'):
    jiwon_dict = {
        '서울중앙지방법원': '서울중앙지방법원',
        '서울동부지방법원': '서울동부지방법원',
        '서울서부지방법원': '서울서부지방법원'
    }
    building_codes = {
        "단독주택": "00008020101",
        "다가구주택": "00008020102",
        "다중주택": "00008020103",
        "아파트": "00008020104",
        "연립주택": "00008020105",
        "다세대주택": "00008020106",
        "기숙사": "00008020107",
        "빌라": "00008020108",
        "상가주택": "00008020109",
        "오피스텔": "00008020110",
        "주상복합": "00008020111"
    }
    jiwon = st.selectbox('법원 선택', list(jiwon_dict.keys()))
    building = st.selectbox('건물 유형', list(building_codes.keys()))
    start_date = st.date_input('시작 날짜')
    end_date = st.date_input('종료 날짜')
    submit_button = st.form_submit_button(label='검색')

if submit_button:
    input_data = {
        'jiwon': jiwon_dict[jiwon],
        'building': building,
        'start_date': start_date.strftime('%Y.%m.%d'),
        'end_date': end_date.strftime('%Y.%m.%d')
    }
    with st.spinner('검색 중...'):
        df = main(input_data, building_codes)
        if df.empty:
            st.warning('검색 결과가 없습니다.')
        else:
            st.dataframe(df)
