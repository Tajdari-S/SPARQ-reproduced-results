#include <iostream>
#include <unordered_map>
#include <vector>
#include <string>
#include <string_view>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <cstring>
#include <cstdlib>
#include <algorithm>
#include <cctype>

// Constants
constexpr int GROUPS = 64;
constexpr size_t H_ROWS = 2500;
constexpr size_t MAX_KEY_LENGTH = 256;

// Hash table type
using HashRow = std::unordered_map<std::string, size_t>;
std::vector<HashRow> H(GROUPS * H_ROWS);

// Duplicate map
std::unordered_map<std::string, std::vector<size_t>> L;

// FNV-1a hash function
inline size_t fnv1a_hash(const std::string_view& key) {
    constexpr size_t FNV_PRIME = 16777619u;
    constexpr size_t FNV_OFFSET = 2166136261u;
    size_t hash = FNV_OFFSET;
    for (char c : key) {
        hash ^= static_cast<size_t>(c);
        hash *= FNV_PRIME;
    }
    return hash;
}

// Hash functions
inline size_t hash_group(const std::string_view& key) {
    return fnv1a_hash(key) % GROUPS;
}
inline size_t hash_row(const std::string_view& key) {
    return (fnv1a_hash(key) / GROUPS) % H_ROWS;
}

// Trim function
std::string_view trim(std::string_view s) {
    size_t start = 0;
    while (start < s.size() && std::isspace(static_cast<unsigned char>(s[start]))) ++start;
    size_t end = s.size();
    while (end > start && std::isspace(static_cast<unsigned char>(s[end - 1]))) --end;
    return s.substr(start, end - start);
}

// Memory-map file
char* mmap_file(const char* filename, size_t& filesize) {
    int fd = open(filename, O_RDONLY);
    if (fd == -1) exit(1);
    struct stat sb;
    if (fstat(fd, &sb) == -1) exit(1);
    filesize = sb.st_size;
    char* data = (char*)mmap(NULL, filesize, PROT_READ, MAP_PRIVATE, fd, 0);
    if (data == MAP_FAILED) exit(1);
    close(fd);
    return data;
}

int main(int argc, char* argv[]) {
    if (argc < 3) return 1;

    // Get target column
    int target_col = std::atoi(argv[2]);
    if (target_col < 0) return 1;

    // Memory map the input file
    size_t filesize = 0;
    char* filedata = mmap_file(argv[1], filesize);

    // Reserve space for H and L
    for (auto& hrow : H) {
        hrow.reserve(50);
    }
    L.reserve(200000);

    // Process file and insert keys
    size_t row_idx = 0;
    size_t key_count = 0;
    size_t next_l_idx = 6001173 + 1;

    double start_time = 0.0;
    {
        struct timespec ts;
        clock_gettime(CLOCK_MONOTONIC, &ts);
        start_time = ts.tv_sec + ts.tv_nsec * 1e-9;
    }

    size_t pos = 0;
    while (pos < filesize) {
        size_t line_start = pos;
        while (pos < filesize && filedata[pos] != '\n') ++pos;
        std::string_view line(filedata + line_start, pos - line_start);
        ++pos;

        // Parse columns
        int col = 0;
        size_t col_start = 0;
        for (size_t i = 0; i <= line.size(); ++i) {
            if (i == line.size() || line[i] == ',') {
                if (col == target_col) {
                    auto key_view = trim(line.substr(col_start, i - col_start));
                    if (!key_view.empty() && key_view.size() <= MAX_KEY_LENGTH) {
                        std::string key(key_view);
                        size_t g = hash_group(key_view);
                        size_t r = hash_row(key_view);
                        if (g < GROUPS && r < H_ROWS) {
                            size_t idx = g * H_ROWS + r;
                            auto& hrow = H[idx];
                            auto it = hrow.find(key);
                            if (it == hrow.end()) {
                                hrow.emplace(key, row_idx);
                            } else {
                                auto& l_list = L[key];
                                if (l_list.empty()) {
                                    l_list.push_back(it->second);
                                    it->second = next_l_idx++;
                                }
                                l_list.push_back(row_idx);
                            }
                            ++key_count;
                        }
                    }
                    break;
                }
                col_start = i + 1;
                ++col;
            }
        }
        ++row_idx;
    }

    double end_time = 0.0;
    {
        struct timespec ts;
        clock_gettime(CLOCK_MONOTONIC, &ts);
        end_time = ts.tv_sec + ts.tv_nsec * 1e-9;
    }

    // Compute statistics
    size_t h_non_empty_rows = 0;
    size_t h_max_cols = 0;
    size_t total_unique = 0;
    for (const auto& hrow : H) {
        if (!hrow.empty()) {
            ++h_non_empty_rows;
            total_unique += hrow.size();
            h_max_cols = std::max(h_max_cols, hrow.size());
        }
    }

    size_t l_rows = L.size();
    size_t l_max_cols = 0;
    for (const auto& [key, indices] : L) {
        l_max_cols = std::max(l_max_cols, indices.size());
    }

    std::cout << "H: " << h_non_empty_rows << " rows, max " << h_max_cols << " columns\n";
    std::cout << "L: " << l_rows << " rows, max " << l_max_cols << " columns\n";
    std::cout << "Unique keys in H: " << total_unique << "\n";
    std::cout << "Duplicate keys in L: " << L.size() << "\n";
    std::cout << "Total time: " << (end_time - start_time) << " seconds\n";
    std::cout << "Average latency per key: " << ((end_time - start_time) / key_count) * 1e6 << " microseconds\n";

    // Cleanup
    munmap(filedata, filesize);

    return 0;
}