import streamlit as st
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait, Select
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.chrome.options import Options # Import Options
from webdriver_manager.chrome import ChromeDriverManager
from bs4 import BeautifulSoup
import urllib.parse
import pandas as pd
import numpy as np
import re
import time # Import time for potential small delays

# --- Setup WebDriver ---
def setup_webdriver():
    chrome_options = Options()
    # Essential for Streamlit Cloud (headless Linux environment)
    chrome_options.add_argument("--headless")
    chrome_options.add_argument("--no-sandbox") # Bypass OS security model, crucial for Linux env
    chrome_options.add_argument("--disable-dev-shm-usage") # Overcome limited resource problems
    chrome_options.add_argument("--window-size=1920,1080") # Set a consistent window size
    chrome_options.add_argument("--start-maximized") # Maximize window to ensure elements are visible
    chrome_options.add_argument("--disable-gpu") # Sometimes helps with stability in headless mode
    # Explicitly set binary location if chromium is installed via packages.txt
    # This is often needed on Streamlit Cloud
    chrome_options.binary_location = "/usr/bin/chromium" # For 'chromium' package
    # If you installed 'google-chrome-stable' via packages.txt, use:
    # chrome_options.binary_location = "/usr/bin/google-chrome-stable"

    try:
        service = Service(ChromeDriverManager().install())
        driver = webdriver.Chrome(service=service, options=chrome_options)
        return driver
    except Exception as e:
        st.error(f"Failed to set up WebDriver: {e}")
        st.stop() # Stop the Streamlit app execution if driver setup fails

# --- Navigation Functions ---
def navigate_to_search_page(driver):
    driver.get("https://www.courtauction.go.kr/")
    wait = WebDriverWait(driver, 20) # Increased wait time

    # Wait for the frame to be available and switch to it
    wait.until(EC.frame_to_be_available_and_switch_to_it("indexFrame"))
    st.write("Switched to indexFrame.")

    # Now, find the search button *within* the frame.
    # Based on the HTML, your initial click was likely outside this frame.
    # The search button might be something like the '물건상세검색' link
    # This link appears to be under 'mf_wfm_mainFrame_wfm_side_PGJ151'
    try:
        # Using the id from the provided HTML: mf_wfm_mainFrame_wfm_side_spn_gdsDtlSrch
        search_button = wait.until(EC.element_to_be_clickable((By.ID, "mf_wfm_mainFrame_wfm_side_spn_gdsDtlSrch")))
        search_button.click()
        st.write("Clicked '물건상세검색' button.")
    except Exception as e:
        st.error(f"Could not click the search button on the main page. Ensure the correct element is targeted: {e}")
        driver.quit() # Clean up driver
        st.stop() # Stop app

    # After clicking, the new content appears in another frame, or the main frame content changes.
    # The search form seems to be within 'mf_wfm_mainFrame_tac_rletMvprpChc_contents_content3_body'
    # It's crucial to ensure the correct frame is active or the page content is loaded.
    # Sometimes, after a click, you might need to re-select the frame or wait for content to load.
    # For now, let's assume the context remains within 'indexFrame' and the content updates.
    wait.until(EC.presence_of_element_located((By.ID, "mf_wfm_mainFrame_wq_uuid_345"))) # Wait for a known element on the search page table
    st.write("Navigated to search criteria page.")


def set_search_criteria(driver, input_data, building_codes):
    wait = WebDriverWait(driver, 10)

    # Court selection (idJiwonNm was mapped to mf_wfm_mainFrame_sbx_rletCortOfc)
    # Ensure it's clickable before selecting
    st.write(f"Attempting to select court: {input_data['jiwon']}")
    setCourt_element = wait.until(EC.element_to_be_clickable((By.ID, 'mf_wfm_mainFrame_sbx_rletCortOfc')))
    setCourt = Select(setCourt_element)
    # The options' values might be the text itself or hidden codes.
    # Let's try by visible text first, as that's what your input_data has.
    setCourt.select_by_visible_text(input_data['jiwon'])
    st.write(f"Selected court: {input_data['jiwon']}")
    time.sleep(1) # Small delay for UI to update if needed

    # Building Type selection
    # Correct IDs for LCL, MCL, SCL (대분류, 중분류, 소분류)
    st.write(f"Attempting to select building type: {input_data['building']}")

    # Select 대분류 (Large Category) - "건물" (Building)
    setLCL_element = wait.until(EC.element_to_be_clickable((By.ID, 'mf_wfm_mainFrame_sbx_rletLclLst')))
    setLCL = Select(setLCL_element)
    setLCL.select_by_value("0000802") # Value for '건물'
    st.write("Selected '건물' (Building) for large category.")
    time.sleep(1) # Give time for 중분류 to load

    # Select 중분류 (Middle Category) - "주거용건물" (Residential Building)
    setMCL_element = wait.until(EC.element_to_be_clickable((By.ID, 'mf_wfm_mainFrame_sbx_rletMclLst')))
    setMCL = Select(setMCL_element)
    setMCL.select_by_value("000080201") # Value for '주거용건물'
    st.write("Selected '주거용건물' (Residential Building) for middle category.")
    time.sleep(1) # Give time for 소분류 to load

    # Select 소분류 (Small Category) - specific building type
    setSCL_element = wait.until(EC.element_to_be_clickable((By.ID, 'mf_wfm_mainFrame_sbx_rletSclLst')))
    setSCL = Select(setSCL_element)
    setSCL.select_by_value(building_codes[input_data['building']])
    st.write(f"Selected '{input_data['building']}' for small category.")
    time.sleep(1) # Small delay for UI to update

    # Date inputs
    # Correct IDs for date input fields
    st.write(f"Setting start date: {input_data['start_date']}")
    time_textbox_start = wait.until(EC.element_to_be_clickable((By.ID, 'mf_wfm_mainFrame_cal_rletPerdStr_input')))
    time_textbox_start.clear()
    time_textbox_start.send_keys(input_data['start_date'])
    st.write(f"Set start date: {input_data['start_date']}")
    time.sleep(0.5)

    st.write(f"Setting end date: {input_data['end_date']}")
    time_textbox_end = wait.until(EC.element_to_be_clickable((By.ID, 'mf_wfm_mainFrame_cal_rletPerdEnd_input')))
    time_textbox_end.clear()
    time_textbox_end.send_keys(input_data['end_date'])
    st.write(f"Set end date: {input_data['end_date']}")
    time.sleep(0.5)

    # Search button
    # Based on the provided HTML, there isn't an immediate search button with the old XPath.
    # The button to click after setting criteria is likely specific to the form.
    # Looking at the full website, it's usually an image button with text "검색" (Search).
    # A common ID is 'mf_wfm_mainFrame_btn_search' or something similar.
    # Let's use the provided xpath '//*[@id="contents"]/form/div[2]/a[1]/img'
    # However, this XPath suggests it's outside the frame 'mf_wfm_mainFrame'.
    # You need to switch out of the frame, click the button, then possibly switch back if needed.

    # Option 1: Switch back to default content, click, then switch back to frame
    # This is a common pattern if the button is NOT inside the current frame.
    driver.switch_to.default_content() # Exit the frame
    st.write("Switched back to default content to click search button.")
    try:
        # This XPath still feels generic. A more robust locator would be better if available.
        # Check the actual '검색' button's ID or more specific XPath in the browser inspector.
        # Example: wait.until(EC.element_to_be_clickable((By.ID, 'specific_search_button_id')))
        search_submit_button = wait.until(EC.element_to_be_clickable((By.XPATH, '//*[@id="contents"]/form/div[2]/a[1]/img')))
        search_submit_button.click()
        st.write("Clicked the main search submit button.")
    except Exception as e:
        st.error(f"Could not click the main search submit button: {e}")
        driver.quit()
        st.stop()

    # After clicking, you might need to re-enter the frame if the results are displayed within it.
    # Or, the page might reload and the results are directly in the default content.
    # Let's assume the results are now in the default content, or the next step will handle finding the table.
    st.write("Waiting for search results to load...")
    # Wait for a table or a known element on the results page.
    # This could be the element with class 'Ltbl_list' that you use in extract_table_data
    try:
        wait.until(EC.presence_of_element_located((By.CLASS_NAME, 'Ltbl_list')))
        st.write("Search results table loaded.")
    except Exception as e:
        st.error(f"Search results table did not load within the expected time: {e}")
        driver.quit()
        st.stop()


def change_items_per_page(driver):
    wait = WebDriverWait(driver, 10)
    try:
        # The 'ipage' dropdown for items per page might be inside the main frame or default content.
        # After clicking the search button, the page likely reloads or navigates.
        # You need to determine if you are still in the frame or in the default content.
        # Assuming you are now in the default content or the table is rendered there.
        # If 'ipage' is directly on the main page after search, this is fine.
        setPage_element = wait.until(EC.element_to_be_clickable((By.ID, 'ipage')))
        setPage = Select(setPage_element)
        setPage.select_by_value("default40")
        st.write("Changed items per page to 40.")
    except Exception as e:
        st.warning(f"Could not find or select 'ipage' dropdown. Attempting to click alternative: {e}")
        # If 'ipage' is not found, it might be an image button or a different UI element.
        # The XPath '//*[@id="contents"]/div[4]/form[1]/div/div/a[4]/img' from your original code
        # suggests clicking a specific button if 'ipage' is not present.
        # This XPath is for an image button usually for page navigation or settings.
        # It's crucial to confirm this element's purpose and if it's visible.
        try:
            alternative_button = wait.until(EC.element_to_be_clickable((By.XPATH, '//*[@id="contents"]/div[4]/form[1]/div/div/a[4]/img')))
            alternative_button.click()
            st.write("Clicked alternative button for items per page/pagination.")
        except Exception as alt_e:
            st.error(f"Failed to change items per page and alternative button also not found: {alt_e}")
            driver.quit()
            st.stop()

# --- Rest of your functions (no changes needed based on current info) ---
def extract_table_data(driver):
    soup = BeautifulSoup(driver.page_source, 'html.parser')
    table = soup.find('table', attrs={'class': 'Ltbl_list'})
    if not table:
        st.warning("Could not find the table with class 'Ltbl_list'.")
        return pd.DataFrame() # Return empty DataFrame if table not found
    table_rows = table.find_all('tr')
    row_list = []
    for tr in table_rows:
        td = tr.find_all('td')
        row = [tr.text for tr in td]
        row_list.append(row)
    return pd.DataFrame(row_list).iloc[1:]

def navigate_pages(driver, aution_item):
    wait = WebDriverWait(driver, 10)
    page = 1
    while True:
        current_page_data = extract_table_data(driver)
        if current_page_data.empty:
            st.write(f"No data found on page {page}, stopping pagination.")
            break # Exit if no data is found (e.g., end of results)

        aution_item = pd.concat([aution_item, current_page_data], ignore_index=True)
        st.write(f"Extracted data from page {page}. Total rows: {len(aution_item)}")

        try:
            # Find the pagination container.
            # This XPath is critical and might change if the page structure is dynamic.
            # Look for a more specific ID if possible, e.g., 'pagination_container_id'
            page2parent = wait.until(EC.presence_of_element_located((By.CLASS_NAME, 'page2')))
            children = page2parent.find_elements(By.XPATH, '*') # Find all direct children (page links)

            # Logic for navigating pages based on the visible page numbers.
            # This logic depends heavily on how the page numbers are rendered and their indices.
            # It's often safer to click specific text (e.g., "다음" for next, or page number).
            if page == 1:
                # If only one page (no next page links) or at the end of the 1-10 block
                if len(children) <= page: # If there's only 1 child (current page) or children count matches current page
                    st.write("Reached last page or only one page of results.")
                    break
                else:
                    # Click the next page number (e.g., if children = [1, 2, 3...], click children[1] for page 2)
                    next_page_link = children[page] # This is typically the next number, e.g., '2' if page=1
                    next_page_link.click()
                    st.write(f"Clicked to page {page + 1}.")
            elif page % 10 == 0: # If current page is a multiple of 10 (e.g., 10, 20), click 'next 10 pages' button
                # This assumes there's a specific "다음" (Next) or ">>" button.
                # You'll need to find the specific locator for the "Next page block" button.
                # Example: find a button containing "다음" text or a specific class/id.
                try:
                    next_block_button = wait.until(EC.element_to_be_clickable((By.XPATH, ".//a[contains(text(), '다음')]"))) # Example for "다음" button
                    next_block_button.click()
                    st.write(f"Clicked '다음' (Next block) button from page {page}.")
                except Exception as e:
                    st.write(f"No '다음' button found or end of pages reached after page {page}. Stopping pagination. Error: {e}")
                    break # No more next block button
            elif page <= 10: # Pages 2-10
                if len(children) - 1 == page: # If current page is the last in the visible block (e.g., page 5, children[5] is the last)
                    st.write(f"Reached last page in current block ({page}).")
                    break # No more pages in this block
                else:
                    next_page_link = children[page + 1] # Click the next number in the sequence (e.g., '3' if page=2)
                    next_page_link.click()
                    st.write(f"Clicked to page {page + 1}.")
            else: # Pages beyond 10, e.g., 11, 12...
                # This logic is more complex for advanced pagination (e.g., 11, 12... 20, >>)
                # It depends on how the page numbers are represented after the 1-10 block.
                # Often, children[(page % 10) + 2] assumes a fixed layout.
                # It's better to find the current page number link and then find its next sibling.
                try:
                    current_page_element = driver.find_element(By.XPATH, f"//span[@class='on' and text()='{page}']") # Find the currently active page number
                    next_page_element = current_page_element.find_element(By.XPATH, "./following-sibling::a[1]") # Find the next 'a' sibling
                    next_page_element.click()
                    st.write(f"Clicked to page {page + 1} (advanced pagination).")
                except Exception as e:
                    st.write(f"Could not find next page element for page {page}. Stopping pagination. Error: {e}")
                    break # No more pages
        except Exception as e:
            st.write(f"Error navigating pagination or no more pages found: {e}")
            break # Exit loop if pagination elements are not found

        page += 1
        time.sleep(1) # Small delay between page loads

    # The line below was clicking an image button after navigation.
    # It seems to be a redundant click or perhaps for re-initiating search if the table wasn't loaded correctly.
    # I've commented it out for now, as it might interfere with the current flow.
    # driver.find_element(By.XPATH, '//*[@id="contents"]/div[4]/form[1]/div/div/a[4]/img').click()
    return aution_item

def clean_table_data(aution_item):
    if aution_item.empty:
        st.write("No data to clean.")
        return aution_item

    # Ensure there are enough columns before slicing.
    # The first column is often empty or row numbers, so skipping it makes sense.
    if aution_item.shape[1] > 1:
        aution_item = aution_item.iloc[:, 1:]
    else:
        st.warning("Table has fewer than 2 columns, skipping first column slice.")
        return pd.DataFrame() # Return empty if data structure is unexpected

    col_list = ['사건번호', '물건번호', '소재지', '비고', '감정평가액', '날짜']
    if len(aution_item.columns) != len(col_list):
        st.error(f"Column count mismatch. Expected {len(col_list)}, got {len(aution_item.columns)}. Data might be structured differently.")
        # Attempt to rename if columns are close, or handle gracefully.
        # For now, let's proceed and allow subsequent errors if parsing fails.
        # It's better to let it fail here than return garbage.
        return pd.DataFrame() # Stop if column count is wrong.

    aution_item.columns = col_list
    for col in col_list:
        if col in aution_item.columns: # Ensure column exists before operating
            aution_item[col] = aution_item[col].astype(str).str.replace('\t', '')
            aution_item[col] = aution_item[col].apply(lambda x: re.sub(r"\n+", "\n", x))
        else:
            st.warning(f"Column '{col}' not found in DataFrame for cleaning.")

    # Apply operations only if columns exist.
    # Adding checks for existing columns to prevent KeyError if parsing fails.
    if '사건번호' in aution_item.columns:
        aution_item['법원'] = aution_item['사건번호'].str.split('\n').str[1]
        aution_item['사건번호'] = aution_item['사건번호'].str.split('\n').str[2]
    if '물건번호' in aution_item.columns:
        aution_item['용도'] = aution_item['물건번호'].str.split('\n').str[2]
        aution_item['물건번호'] = aution_item['물건번호'].str.split('\n').str[1]
    if '소재지' in aution_item.columns:
        aution_item['내역'] = aution_item['소재지'].str.split('\n').str[2:].str.join(' ')
        aution_item['소재지'] = aution_item['소재지'].str.split('\n').str[1]
    if '비고' in aution_item.columns:
        aution_item['비고'] = aution_item['비고'].str.split('\n').str[1]
    if '감정평가액' in aution_item.columns:
        aution_item['최저가격'] = aution_item['감정평가액'].str.split('\n').str[2]
        # Check if str[3] exists before slicing
        temp_str_3 = aution_item['감정평가액'].str.split('\n').str[3]
        aution_item['최저비율'] = temp_str_3.str[1:-1] if not temp_str_3.empty else ''
        aution_item['감정평가액'] = aution_item['감정평가액'].str.split('\n').str[1]
    if '날짜' in aution_item.columns:
        temp_str_3_date = aution_item['날짜'].str.split('\n').str[3].str.strip()
        aution_item['유찰횟수'] = np.where(temp_str_3_date.str.len() == 0, '0회', temp_str_3_date.str.slice(start=2))
        aution_item['날짜'] = aution_item['날짜'].str.split('\n').str[2]


    # Reorder columns and filter if all necessary columns exist.
    required_final_cols = ['날짜', '법원', '사건번호', '물건번호', '용도', '감정평가액', '최저가격', '최저비율', '유찰횟수', '소재지', '내역', '비고']
    if all(col in aution_item.columns for col in required_final_cols):
        aution_item = aution_item[required_final_cols]
    else:
        st.error("Some final required columns are missing after cleaning.")
        return pd.DataFrame() # Stop if essential columns are missing.

    # Filter out '지분매각' if '비고' column exists and is not empty
    if '비고' in aution_item.columns and not aution_item['비고'].empty:
        aution_item = aution_item[~aution_item['비고'].astype(str).str.contains('지분매각', na=False)].reset_index(drop=True)
    return aution_item

def encode_to_euc_kr_url(korean_text):
    euc_kr_encoded = korean_text.encode('euc-kr')
    return urllib.parse.quote(euc_kr_encoded)

def create_url(row):
    court_name_encoded = encode_to_euc_kr_url(row["법원"])
    sa_year, sa_ser = row["사건번호"].split("타경")
    url = f"https://www.courtauction.go.kr/RetrieveRealEstDetailInqSaList.laf?jiwonNm={court_name_encoded}&saYear={sa_year}&saSer={sa_ser}&_CUR_CMD=InitMulSrch.laf&_SRCH_SRNID=PNO102014&_NEXT_CMD=RetrieveRealEstDetailInqSaList.laf"
    return url

# --- Main Application Logic ---
def main(input_data, building_codes):
    st.write("Starting main function...")
    driver = setup_webdriver()
    try:
        navigate_to_search_page(driver)
        set_search_criteria(driver, input_data, building_codes)
        change_items_per_page(driver) # This might not be strictly necessary, or might fail if no results
        
        auction_data = pd.DataFrame()
        auction_data = navigate_pages(driver, auction_data)
        
        if not auction_data.empty:
            auction_data = clean_table_data(auction_data)
            if not auction_data.empty: # Check again after cleaning
                auction_data["URL"] = auction_data.apply(create_url, axis=1)
                st.success("Data scraping and processing complete!")
            else:
                st.warning("No data left after cleaning.")
        else:
            st.warning("No auction data found for the given criteria.")
            
    except Exception as e:
        st.error(f"An error occurred during the scraping process: {e}")
        auction_data = pd.DataFrame() # Ensure auction_data is defined even on error
    finally:
        if driver:
            driver.quit()
            st.write("WebDriver closed.")
    return auction_data

# --- Streamlit UI ---
st.title('법원 경매 검색')

# Input form
with st.form(key='search_form'):
    jiwon = st.selectbox('지원', ['서울중앙지방법원', '서울동부지방법원', '서울서부지방법원', '서울남부지방법원', '서울북부지방법원',
                                  '의정부지방법원', '고양지원', '남양주지원', '인천지방법원', '부천지원',
                                  '수원지방법원', '성남지원', '여주지원', '평택지원', '안산지원', '안양지원',
                                  '춘천지방법원', '강릉지원', '원주지원', '속초지원', '영월지원',
                                  '청주지방법원', '충주지원', '제천지원', '영동지원', '대전지방법원',
                                  '홍성지원', '논산지원', '천안지원', '공주지원', '서산지원', '대구지방법원',
                                  '안동지원', '경주지원', '김천지원', '상주지원', '의성지원', '영덕지원',
                                  '포항지원', '대구서부지원', '부산지방법원', '부산동부지원', '부산서부지원',
                                  '울산지방법원', '창원지방법원', '마산지원', '진주지원', '통영지원',
                                  '밀양지원', '거창지원', '광주지방법원', '목포지원', '장흥지원',
                                  '순천지원', '해남지원', '전주지방법원', '군산지원', '정읍지원',
                                  '남원지원', '제주지방법원'])
    building = st.selectbox('건물 유형', ["단독주택", "다가구주택", "다중주택", "아파트", "연립주택", "다세대주택", "기숙사", "빌라", "상가주택", "오피스텔", "주상복합"])
    
    # Set default dates to today - 3 months and today
    today = datetime.date.today()
    three_months_ago = today - datetime.timedelta(days=90)
    
    start_date = st.date_input('시작 날짜', value=three_months_ago)
    end_date = st.date_input('종료 날짜', value=today)
    
    submit_button = st.form_submit_button(label='검색')

import datetime # Ensure datetime is imported at the top

if submit_button:
    input_data = {
        'jiwon': jiwon,
        'building': building,
        'start_date': start_date.strftime('%Y.%m.%d'),
        'end_date': end_date.strftime('%Y.%m.%d')
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

    auction_data = main(input_data, building_codes)
    if not auction_data.empty:
        st.dataframe(auction_data)
    else:
        st.info("No data to display. Please check the logs for errors or adjust your search criteria.")
