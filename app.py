import streamlit as st
import requests
import json

st.title("법원 경매 물건 검색기 (JSON API)")

# Streamlit 입력 폼 예시 (실제로는 API 파라미터에 맞게 커스터마이즈 필요)
with st.form("search_form"):
    cortOfcCd = st.text_input("법원코드(예: B000210)", value="B000210")
    bidBgngYmd = st.date_input("경매시작일", value="2025-06-18")
    bidEndYmd = st.date_input("경매종료일", value="2025-07-02")
    sclDspslGdsLstUsgCd = st.selectbox(
        "건물유형코드(예: 아파트)",
        ["20104", "20101", "20102", "20103", "20105", "20106", "20107", "20108", "20109", "20110", "20111"],
        index=0
    )
    submit = st.form_submit_button("검색")

if submit:
    url = "https://www.courtauction.go.kr/pgj/pgjsearch/searchControllerMain.on"
    headers = {
        "Accept": "application/json",
        "Accept-Language": "ko-KR,ko;q=0.9",
        "Content-Type": "application/json;charset=UTF-8",
        "Origin": "https://www.courtauction.go.kr",
        "Referer": "https://www.courtauction.go.kr/pgj/index.on?w2xPath=/pgj/ui/pgj100/PGJ151F00.xml",
        "SC-Userid": "SYSTEM",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36",
        "sec-ch-ua": '"Google Chrome";v="137", "Chromium";v="137", "Not/A)Brand";v="24"',
        "sec-ch-ua-mobile": "?0",
        "sec-ch-ua-platform": '"Windows"',
        "submissionid": "mf_wfm_mainFrame_sbm_selectGdsDtlSrch"
    }
    cookies = {
        "WMONID": "MdVTumwHWMQ",
        "JSESSIONID": "KCCA2BDPF9df-U8ZnINo6hykDuqYTOlc6UJ4pSWbQeKY5CNpcnn1!345867374",
        "cortAuctnLgnMbr": "",
        "wcCookieV2": "115.91.150.54_T_945218_WC",
        "lastAccess": "1750213458681"
    }
    data = {
        "dma_pageInfo": {
            "pageNo": 1,
            "pageSize": 10,
            "bfPageNo": 1,
            "startRowNo": 1,
            "totalCnt": "",
            "totalYn": "N",
            "groupTotalCount": 0
        },
        "dma_srchGdsDtlSrchInfo": {
            "rletDspslSpcCondCd": "",
            "bidDvsCd": "000331",
            "mvprpRletDvsCd": "00031R",
            "cortAuctnSrchCondCd": "0004601",
            "rprsAdongSdCd": "11",
            "rprsAdongSggCd": "",
            "rprsAdongEmdCd": "",
            "rdnmSdCd": "",
            "rdnmSggCd": "",
            "rdnmNo": "",
            "mvprpDspslPlcAdongSdCd": "",
            "mvprpDspslPlcAdongSggCd": "",
            "mvprpDspslPlcAdongEmdCd": "",
            "rdDspslPlcAdongSdCd": "",
            "rdDspslPlcAdongSggCd": "",
            "rdDspslPlcAdongEmdCd": "",
            "cortOfcCd": cortOfcCd,
            "jdbnCd": "",
            "execrOfcDvsCd": "",
            "lclDspslGdsLstUsgCd": "20000",
            "mclDspslGdsLstUsgCd": "20100",
            "sclDspslGdsLstUsgCd": sclDspslGdsLstUsgCd,
            "cortAuctnMbrsId": "",
            "aeeEvlAmtMin": "",
            "aeeEvlAmtMax": "",
            "lwsDspslPrcRateMin": "",
            "lwsDspslPrcRateMax": "",
            "flbdNcntMin": "",
            "flbdNcntMax": "",
            "objctArDtsMin": "",
            "objctArDtsMax": "",
            "mvprpArtclKndCd": "",
            "mvprpArtclNm": "",
            "mvprpAtchmPlcTypCd": "",
            "notifyLoc": "on",
            "lafjOrderBy": "",
            "pgmId": "PGJ151F01",
            "csNo": "",
            "cortStDvs": "2",
            "statNum": 1,
            "bidBgngYmd": bidBgngYmd.strftime("%Y%m%d"),
            "bidEndYmd": bidEndYmd.strftime("%Y%m%d"),
            "dspslDxdyYmd": "",
            "fstDspslHm": "",
            "scndDspslHm": "",
            "thrdDspslHm": "",
            "fothDspslHm": "",
            "dspslPlcNm": "",
            "lwsDspslPrcMin": "",
            "lwsDspslPrcMax": "",
            "grbxTypCd": "",
            "gdsVendNm": "",
            "fuelKndCd": "",
            "carMdyrMax": "",
            "carMdyrMin": "",
            "carMdlNm": ""
        }
    }
    with st.spinner("검색 중..."):
        try:
            response = requests.post(
                url,
                headers=headers,
                cookies=cookies,
                data=json.dumps(data, ensure_ascii=False).encode("utf-8")
            )
            if response.status_code == 200:
                result = response.json()
                st.json(result)  # JSON 결과 전체 출력
                # 결과가 리스트/테이블 형태라면, 아래처럼 DataFrame으로 변환 가능
                # import pandas as pd
                # df = pd.DataFrame(result['dma_srchGdsDtlSrchInfoList'])
                # st.dataframe(df)
            else:
                st.error(f"요청 실패: {response.status_code}")
        except Exception as e:
            st.error(f"오류 발생: {e}")
