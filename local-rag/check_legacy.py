"""Do the imports from older LangChain tutorials still work?"""
for stmt in ["from langchain.text_splitter import RecursiveCharacterTextSplitter",
             "from langchain.chains import RetrievalQA",
             "from langchain.prompts import PromptTemplate",
             "from langchain_classic.chains import RetrievalQA"]:
    try:
        exec(stmt); print("OK     ", stmt)
    except Exception as e:
        print("FAILS  ", stmt, "->", type(e).__name__, str(e)[:120])
