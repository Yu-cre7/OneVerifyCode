#import <Cocoa/Cocoa.h>
#import "OVCIconFactory.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];

        if (argc < 2) {
            fprintf(stderr, "usage: icongen <out.iconset>\n");
            return 2;
        }
        NSString *directory = [NSString stringWithUTF8String:argv[1]];
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:directory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        if (error) {
            fprintf(stderr, "mkdir failed: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }

        NSArray<NSArray<id> *> *entries = @[
            @[@"icon_16x16.png", @16],
            @[@"icon_16x16@2x.png", @32],
            @[@"icon_32x32.png", @32],
            @[@"icon_32x32@2x.png", @64],
            @[@"icon_128x128.png", @128],
            @[@"icon_128x128@2x.png", @256],
            @[@"icon_256x256.png", @256],
            @[@"icon_256x256@2x.png", @512],
            @[@"icon_512x512.png", @512],
            @[@"icon_512x512@2x.png", @1024],
        ];

        for (NSArray<id> *entry in entries) {
            NSString *name = entry[0];
            NSInteger size = [entry[1] integerValue];
            NSURL *url = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:name]];
            NSError *writeError = nil;
            if (![OVCIconFactory writeAppIconPNGToURL:url pixelSize:size error:&writeError]) {
                fprintf(stderr, "failed %s: %s\n", name.UTF8String,
                        writeError.localizedDescription.UTF8String ?: "unknown");
                return 1;
            }
            printf("wrote %s (%ld px)\n", name.UTF8String, (long)size);
        }
        return 0;
    }
}
