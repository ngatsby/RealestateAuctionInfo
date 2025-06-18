import streamlit as st
import requests
from bs4 import BeautifulSoup
import pandas as pd

st.title("법원 경매 물건 검색기 (requests+BeautifulSoup)")

# Streamlit 입력 폼
with st.form("search_form"):
    jiwon = st.selectbox(
        "법원",
        ["서울중앙지방법원", "서울동부지방법원", "서울서부지방법원"],
        index=0
    )
    building = st.selectbox(
        "건물 유형",
        ["아파트", "단독주택", "다가구주택", "다중주택", "연립주택", "다세대주택", "기숙사", "빌라", "상가주택", "오피스텔", "주상복합"],
        index=0
    )
    start_date = st.date_input("시작 날짜")
    end_date = st.date_input("종료 날짜")
    submit = st.form_submit_button("검색")

if submit:
    url = "https://www.courtauction.go.kr/RetrieveRealEstMulDetailList.laf"
    # 아래 form_data, headers, cookies는 개발자도구에서 복사해서 붙여넣어야 합니다!
    # 아래는 예시입니다. 실제로는 네트워크 탭에서 요청을 확인해서 값을 넣어주세요!
    form_data = {
        'idJiwonNm': jiwon,
        'lclsUtilCd': '0000802',  # 부동산
        'mclsUtilCd': '000080201',  # 주거용
        'sclsUtilCd': {  # 건물 유형 코드 예시 (아파트)
            "아파트": "00008020104",
            "단독주택": "00008020101",
            "다가구주택": "00008020102",
            "다중주택": "00008020103",
            "연립주택": "00008020105",
            "다세대주택": "00008020106",
            "기숙사": "00008020107",
            "빌라": "00008020108",
            "상가주택": "00008020109",
            "오피스텔": "00008020110",
            "주상복합": "00008020111"
        }[building],
        'termStartDt': start_date.strftime('%Y.%m.%d'),
        'termEndDt': end_date.strftime('%Y.%m.%d'),
        # 'srchYn': 'Y',  # 필요시 추가
    }
    # 세션 유지가 필요하다면 cookies, headers도 추가해야 합니다.
    # 아래는 예시입니다!
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
        'Referer': 'https://www.courtauction.go.kr/'
    }
    # 쿠키는 네트워크 탭에서 확인해서 넣어주세요!
    cookies = {
        # 'JSESSIONID': '...',
        # 'WMONID': '...',
    }
    # 실제 요청
    with st.spinner('검색 중...'):
        try:
            response = requests.post(url, headers=headers, data=form_data, cookies=cookies)
            soup = BeautifulSoup(response.text, 'lxml')
            table = soup.find('table', attrs={'class': 'Ltbl_list'})
            rows = []
            if table:
                for tr in table.find_all('tr')[1:]:
                    tds = [td.get_text(strip=True) for td in tr.find_all('td')]
                    if tds:
                        rows.append(tds)
                df = pd.DataFrame(rows)
                st.dataframe(df)
                if df.empty:
                    st.warning("검색 결과가 없습니다.")
            else:
                st.warning("테이블을 찾을 수 없습니다. 사이트 구조가 변경되었거나, 요청 파라미터를 확인해주세요.")
        except Exception as e:
            st.error(f"오류가 발생했습니다: {e}")
