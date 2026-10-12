//
//  TDTagWriter.mm
//
//  TagLib's PropertyMap maps one set of names onto ID3v2, MP4 atoms, Vorbis comments
//  and RIFF INFO, so this file needs no per-format code — with one exception:
//
//   * GROUPING. TagLib 2 maps it to ID3v2 GRP1 (what Music 12.5+ writes) and maps
//     TIT1 to WORK. SetlistManager.readMetadata — and older Music, and most tango
//     libraries — read grouping from TIT1. So for ID3v2-carrying files the value
//     goes to both frames.
//

#import "include/TDTagWriter.h"

#include <taglib/fileref.h>
#include <taglib/tpropertymap.h>
#include <taglib/mpegfile.h>
#include <taglib/aifffile.h>
#include <taglib/wavfile.h>

static TagLib::String TDString(NSString *s) {
    return TagLib::String(s.UTF8String, TagLib::String::UTF8);
}

BOOL TDWriteTags(NSString *path,
                 NSDictionary<NSString *, NSString *> *tags,
                 NSString **outError) {
    TagLib::FileRef ref(path.fileSystemRepresentation);
    if (ref.isNull()) {
        if (outError) *outError = @"File type not supported for tag writing";
        return NO;
    }

    TagLib::File *file = ref.file();
    bool carriesID3v2 = dynamic_cast<TagLib::MPEG::File *>(file)
                     || dynamic_cast<TagLib::RIFF::AIFF::File *>(file)
                     || dynamic_cast<TagLib::RIFF::WAV::File *>(file);

    TagLib::PropertyMap props = file->properties();
    for (NSString *key in tags) {
        NSString *value = tags[key];
        TagLib::String k = TDString(key);
        if (value.length == 0) {
            props.erase(k);
            if (carriesID3v2 && [key isEqualToString:@"GROUPING"]) props.erase("WORK");
        } else {
            props.replace(k, TagLib::StringList(TDString(value)));
            if (carriesID3v2 && [key isEqualToString:@"GROUPING"])
                props.replace("WORK", TagLib::StringList(TDString(value)));
        }
    }
    file->setProperties(props);   // unsupported leftovers (e.g. WORK in RIFF INFO) are ignored

    if (!file->save()) {
        if (outError) *outError = @"Could not save tags — is the file read-only?";
        return NO;
    }
    return YES;
}
