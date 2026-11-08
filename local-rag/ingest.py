import time
from langchain_community.document_loaders import PyPDFDirectoryLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_ollama import OllamaEmbeddings
from langchain_community.vectorstores import FAISS

DOCS_DIR = "./docs"
FAISS_INDEX = "./faiss_index"
EMBED_MODEL = "nomic-embed-text"
OLLAMA_BASE_URL = "http://127.0.0.1:11500"

def ingest():
    t0 = time.perf_counter()
    raw_docs = PyPDFDirectoryLoader(DOCS_DIR).load()
    print(f"Loaded {len(raw_docs)} pages from {DOCS_DIR}")
    splitter = RecursiveCharacterTextSplitter(chunk_size=512, chunk_overlap=64)
    chunks = splitter.split_documents(raw_docs)
    print(f"Split into {len(chunks)} chunks")
    embeddings = OllamaEmbeddings(model=EMBED_MODEL, base_url=OLLAMA_BASE_URL)
    vectorstore = FAISS.from_documents(chunks, embeddings)
    vectorstore.save_local(FAISS_INDEX)
    print(f"FAISS index saved to {FAISS_INDEX} in {time.perf_counter() - t0:.1f} s")

if __name__ == "__main__":
    ingest()
