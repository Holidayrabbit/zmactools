#ifndef ZMT_CORE_H
#define ZMT_CORE_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Converts a local file URL (for example, file:///Users/me/My%20Folder)
 * into a normalized absolute path.
 *
 * The returned string is owned by zmt-core and must be released with
 * zmt_string_free(). Returns NULL when the URL cannot be converted.
 */
char *zmt_path_from_file_url(const char *file_url);

/**
 * Releases a string previously returned by this library.
 */
void zmt_string_free(char *string);

#ifdef __cplusplus
}
#endif

#endif

