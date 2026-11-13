//! Shared primitives for ZMacTools.
//!
//! macOS UI integration stays in Swift because Finder Sync extensions are
//! AppKit app extensions. Non-UI behavior lives here and is exposed through a
//! deliberately small C ABI.

use std::ffi::{c_char, CStr, CString};
use std::fmt;

#[derive(Debug, PartialEq, Eq)]
pub enum PathError {
    InvalidUrl,
    NotAFileUrl,
    UnsupportedAuthority,
    InvalidPercentEncoding,
    NotAnAbsolutePath,
    NonUtf8Path,
    NulByte,
}

impl fmt::Display for PathError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(match self {
            Self::InvalidUrl => "invalid URL",
            Self::NotAFileUrl => "URL does not use the file scheme",
            Self::UnsupportedAuthority => "file URL uses an unsupported host",
            Self::InvalidPercentEncoding => "file URL contains an invalid percent escape",
            Self::NotAnAbsolutePath => "file URL did not produce an absolute path",
            Self::NonUtf8Path => "path is not valid UTF-8",
            Self::NulByte => "path contains a NUL byte",
        })
    }
}

impl std::error::Error for PathError {}

/// Converts a Finder item URL into the path users expect to paste elsewhere.
///
/// This does not touch the filesystem. In particular, it does not resolve
/// symlinks or require the target to exist, which keeps it safe for Finder
/// aliases and remote or transient selections.
pub fn path_from_file_url(raw_url: &str) -> Result<String, PathError> {
    let (scheme, remainder) = raw_url
        .split_once("://")
        .ok_or(PathError::InvalidUrl)?;
    if !scheme.eq_ignore_ascii_case("file") {
        return Err(PathError::NotAFileUrl);
    }

    let encoded_path = if remainder.starts_with('/') {
        remainder
    } else {
        let authority_length = remainder.find('/').ok_or(PathError::InvalidUrl)?;
        let authority = &remainder[..authority_length];
        if !authority.is_empty() && !authority.eq_ignore_ascii_case("localhost") {
            return Err(PathError::UnsupportedAuthority);
        }
        &remainder[authority_length..]
    };

    let path = percent_decode(encoded_path)?;
    normalize_absolute_path(&path)
}

fn percent_decode(encoded: &str) -> Result<String, PathError> {
    let bytes = encoded.as_bytes();
    let mut decoded = Vec::with_capacity(bytes.len());
    let mut index = 0;

    while index < bytes.len() {
        if bytes[index] != b'%' {
            decoded.push(bytes[index]);
            index += 1;
            continue;
        }

        if index + 2 >= bytes.len() {
            return Err(PathError::InvalidPercentEncoding);
        }
        let high = hex_value(bytes[index + 1])?;
        let low = hex_value(bytes[index + 2])?;
        decoded.push((high << 4) | low);
        index += 3;
    }

    if decoded.contains(&0) {
        return Err(PathError::NulByte);
    }
    String::from_utf8(decoded).map_err(|_| PathError::NonUtf8Path)
}

fn hex_value(byte: u8) -> Result<u8, PathError> {
    match byte {
        b'0'..=b'9' => Ok(byte - b'0'),
        b'a'..=b'f' => Ok(byte - b'a' + 10),
        b'A'..=b'F' => Ok(byte - b'A' + 10),
        _ => Err(PathError::InvalidPercentEncoding),
    }
}

fn normalize_absolute_path(path: &str) -> Result<String, PathError> {
    if !path.starts_with('/') {
        return Err(PathError::NotAnAbsolutePath);
    }
    if path == "/" {
        return Ok("/".to_owned());
    }

    let normalized = path.trim_end_matches('/');
    if normalized.is_empty() {
        return Ok("/".to_owned());
    }
    Ok(normalized.to_owned())
}

/// Converts a local file URL into an owned C string.
///
/// # Safety
///
/// `file_url` must be either null or a valid, NUL-terminated C string.
#[no_mangle]
pub unsafe extern "C" fn zmt_path_from_file_url(file_url: *const c_char) -> *mut c_char {
    if file_url.is_null() {
        return std::ptr::null_mut();
    }

    let Ok(raw_url) = CStr::from_ptr(file_url).to_str() else {
        return std::ptr::null_mut();
    };
    let Ok(path) = path_from_file_url(raw_url) else {
        return std::ptr::null_mut();
    };

    CString::new(path)
        .map(CString::into_raw)
        .unwrap_or(std::ptr::null_mut())
}

/// Releases a string returned by `zmt_path_from_file_url`.
///
/// # Safety
///
/// `string` must be null or a pointer previously returned by this library and
/// not already freed.
#[no_mangle]
pub unsafe extern "C" fn zmt_string_free(string: *mut c_char) {
    if !string.is_null() {
        drop(CString::from_raw(string));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn converts_plain_folder_url() {
        assert_eq!(
            path_from_file_url("file:///Users/alice/Projects"),
            Ok("/Users/alice/Projects".to_owned())
        );
    }

    #[test]
    fn decodes_spaces_and_unicode() {
        assert_eq!(
            path_from_file_url("file:///Users/alice/My%20Projects/%E4%B8%AD%E6%96%87"),
            Ok("/Users/alice/My Projects/中文".to_owned())
        );
    }

    #[test]
    fn removes_a_trailing_slash() {
        assert_eq!(
            path_from_file_url("file:///Users/alice/Projects/"),
            Ok("/Users/alice/Projects".to_owned())
        );
    }

    #[test]
    fn preserves_the_filesystem_root() {
        assert_eq!(path_from_file_url("file:///"), Ok("/".to_owned()));
        assert_eq!(path_from_file_url("file:////"), Ok("/".to_owned()));
    }

    #[test]
    fn rejects_other_url_schemes() {
        assert_eq!(
            path_from_file_url("https://example.com/folder"),
            Err(PathError::NotAFileUrl)
        );
    }

    #[test]
    fn rejects_invalid_urls() {
        assert_eq!(path_from_file_url("not a URL"), Err(PathError::InvalidUrl));
    }

    #[test]
    fn accepts_localhost_authority() {
        assert_eq!(
            path_from_file_url("file://localhost/Users/alice"),
            Ok("/Users/alice".to_owned())
        );
    }

    #[test]
    fn rejects_remote_authorities() {
        assert_eq!(
            path_from_file_url("file://example.com/Users/alice"),
            Err(PathError::UnsupportedAuthority)
        );
    }

    #[test]
    fn rejects_broken_percent_escapes() {
        assert_eq!(
            path_from_file_url("file:///Users/alice/%ZZ"),
            Err(PathError::InvalidPercentEncoding)
        );
        assert_eq!(
            path_from_file_url("file:///Users/alice/%2"),
            Err(PathError::InvalidPercentEncoding)
        );
    }

    #[test]
    fn rejects_encoded_nul_bytes() {
        assert_eq!(
            path_from_file_url("file:///Users/alice/%00hidden"),
            Err(PathError::NulByte)
        );
    }
}

