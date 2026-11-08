import sys, time
from langchain_ollama import OllamaEmbeddings, ChatOllama
from langchain_community.vectorstores import FAISS
from langchain_core.prompts import ChatPromptTemplate

FAISS_INDEX = "./faiss_index"
EMBED_MODEL = "nomic-embed-text"
LLM_MODEL = sys.argv[1] if len(sys.argv) > 1 else "gemma4:e4b"
OLLAMA_BASE_URL = "http://127.0.0.1:11500"

PROMPT = ChatPromptTemplate.from_template(
    "Answer the question using only the context below. "
    "If the answer is not in the context, say \"I don't know based on the provided documents.\"\n\n"
    "Context:\n{context}\n\nQuestion: {question}\nAnswer:")

embeddings = OllamaEmbeddings(model=EMBED_MODEL, base_url=OLLAMA_BASE_URL)
store = FAISS.load_local(FAISS_INDEX, embeddings, allow_dangerous_deserialization=True)
retriever = store.as_retriever(search_kwargs={"k": 3})
llm = ChatOllama(model=LLM_MODEL, base_url=OLLAMA_BASE_URL, temperature=0)

def ask(question):
    t0 = time.perf_counter()
    docs = retriever.invoke(question)
    context = "\n\n".join(d.page_content for d in docs)
    answer = (PROMPT | llm).invoke({"context": context, "question": question}).content
    pages = sorted({d.metadata.get("page_label") or d.metadata.get("page") for d in docs}, key=str)
    print(f"\nQ: {question}\nA: {answer.strip()}\nSources: northwind-handbook.pdf pages {pages}  ({time.perf_counter() - t0:.1f} s)")

print(f"model: {LLM_MODEL}")
for q in ["How long do customers have to ask for a refund?",
          "How much does the Team plan cost, and how many users does it include?",
          "How often are backups taken?",
          "Who is the CEO of Northwind Labs?"]:
    ask(q)
