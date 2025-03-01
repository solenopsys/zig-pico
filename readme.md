

# Picozig  

🚀 **Ultra-fast HTTP parser in pure Zig**  

Inspired by [picohttpparser](https://github.com/h2o/picohttpparser), this is a partial translation optimized for speed and simplicity.  

### ⚡ Performance  
- Parses **~4 million headers per second** (without SSE4)  
- Outperforms the original picohttpparser (~3.2M headers/sec)  
- Implemented in **pure Zig**, with **zero system calls**  

### ✨ Features  
- Minimal and high-performance  
- No unnecessary system dependencies  
- **Chunked encoding is not implemented** (often unnecessary)  

### 🔥 Benchmark  
```sh
zig run -O ReleaseFast bench.zig
```

### ✅ Run Tests  
```sh
zig test test.zig
```  

