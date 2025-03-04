

# Picozig  

🚀 **Ultra-fast HTTP request parser in pure Zig**  

Inspired by [picohttpparser](https://github.com/h2o/picohttpparser), this is a partial translation optimized for speed and simplicity.  

### ⚡ Performance  
- Parses **>5.2 million requests per second** (without SSE4)  
- Outperforms the original picohttpparser (~3.2M headers/sec without SSE4)  
- Implemented in **pure Zig**, with **zero system calls**  

### ✨ Features  
- Minimal and high-performance  
- No unnecessary system dependencies  
- **Chunked encoding is not implemented** (often unnecessary)  

### 🔥 Benchmark  
```sh
zig run -O ReleaseFast src/request/bench.zig
```
- Result: 5246000 RPS on AMD 8845H mobile CPU

### ✅ Run Tests  
```sh
zig test src/request/test.zig
```  

