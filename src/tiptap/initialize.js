function(instance, context) {

  

    try {
        // add display: flex to main element
        instance.canvas.css("display", "flex");

        // this boolean turns true after the setup has been done, but the editor might not yet be initialized.
        // if the setup runs twice, it can add double initial data, etc.
        instance.data.isEditorSetup = false;

        // this boolean turns true when the editor is initialized and ready.
        instance.data.editor_is_ready = false;

        instance.publishState("is_ready", false);

        //    instance.canvas.cfss({'overflow':'scroll'});

        instance.data.stylesheet = document.createElement("style");
        instance.canvas.append(instance.data.stylesheet);

        // function to find the nearest parent.
        // useful when Tiptap is used inside a repeating group
        function findElement(elementID) {
            let $parent = instance.canvas.parent();
            while ($parent.length > 0) {
                var $foundMenu = $parent.find("#" + elementID);

                if ($foundMenu.length > 0) {
                    return $foundMenu[0];
                }

                $parent = $parent.parent();
            }
        }
        instance.data.findElement = findElement;

        instance.data.isProgrammaticUpdate = false;
        instance.data.delay = 300;

        instance.data.debounce = function debounce(
        cb,
         delay = instance.data.delay
        ) {
            let timeout;
            return (...args) => {
                clearTimeout(timeout); // Clear the existing timeout
                timeout = setTimeout(() => {
                    cb(...args);
                }, instance.data.delay);
                instance.data.debounceTimeout = timeout; // Store the timeout ID
            };
        };

        instance.data.isDebouncingDone = true;
        instance.data.updateContent = instance.data.debounce((content) => {
            console.log("debounce done, updating content");
            instance.publishAutobinding(content);
            instance.triggerEvent("contentUpdated");
            instance.data.isDebouncingDone = true;
        }, instance.data.delay);

        // throttle function: to take it easy on the autobinding.
        // 1. writes to autobinding
        // 2. then waits a certain delay
        // 3. then writes again if the user created more changes
        // source: from https://blog.webdevsimplified.com/2022-03/debounce-vs-throttle

        function throttle(mainFunction, delay = 2000) {
            let timerFlag = null; // Variable to keep track of the timer

            // Returning a throttled version
            return (...args) => {
                if (timerFlag === null) {
                    // If there is no timer currently running
                    mainFunction(...args); // Execute the main function
                    timerFlag = setTimeout(() => {
                        // Set a timer to clear the timerFlag after the specified delay
                        mainFunction(...args);
                        timerFlag = null; // Clear the timerFlag to allow the main function to be executed again
                    }, delay);
                }
            };
        }
        instance.data.throttle = throttle;

        instance.data.throttledContentUpdated = instance.data.throttle(() => {
            instance.triggerEvent("contentUpdated");
            // console.log("getHTML", instance.data.editor.getHTML());
            instance.data.throttle(
                instance.publishAutobinding(instance.data.editor.getHTML())
            );
        });

        function returnAndReportErrorIfEditorNotReady(errorFragment = "error") {
            const message =
                  "Tried to run " +
                  errorFragment +
                  " before editor was ready. Crash prevented. Returning";
            console.log(message);
            context.reportDebugger(message);
            return;
        }
        instance.data.returnAndReportErrorIfEditorNotReady =
            returnAndReportErrorIfEditorNotReady;

        function maybeSetupCollaboration(
        instance,
         properties,
         options,
         extensions
        ) {
            if (properties.collab_active === false) return;
            // removes initialContent -- normally a collab document will have some document in the cloud.
            delete options.content;

            if (!properties.collab_active) {
                console.log("collab is not active");
                return;
            }
            if (properties.collabProvider === "liveblocks") {
                setupLiveblocks(extensions, properties);
                return;
            }

            if (properties.collabProvider === "tiptap") {
                setupTiptapCloud(extensions, properties);
                return;
            }

            if (properties.collabProvider === "custom") {
                setupCustomHocuspocus(extensions, properties);
                return;
            }
        }
        instance.data.maybeSetupCollaboration = maybeSetupCollaboration;

        function setupCustomHocuspocus(extensions, properties) {
            console.log("setting up custom collab");
            const HocusPocusProvider = window.tiptapHocuspocusProvider;
            const Collaboration = window.tiptapCollaboration;
            const CollaborationCursor = window.tiptapCollaborationCursor;
            const Y = window.tiptapY;
            if (!properties.collab_url.endsWith("/")) {
                properties.collab_url += "/";
            }

            const custom_url = properties.collab_url + properties.collab_app_id;
            try {
                instance.data.provider = new HocusPocusProvider({
                    url: custom_url,
                    name: properties.collab_doc_id,
                    token: properties.collab_jwt,
                    onStatus: (event) => {
                        console.log("onStatus event: " + JSON.stringify(event));
                    },
                    onOpen: () => {
                        console.log("onOpen");
                    },
                    onConnect() {
                        console.log("onConnect");
                    },
                    onAuthenticated() {
                        console.log("onAuthenticated");
                    },
                    onAuthenticationFailed: ({ reason }) => {
                        console.log("onAuthenticationFailed", reason);
                    },
                    onSynced: ({ state }) => {
                        console.log("onSynced, state", JSON.stringify(state));
                    },
                    onClose: ({ event }) => {
                        console.log("onClose, event", JSON.stringify(event));
                    },
                    onDisconnect: ({ event }) => {
                        console.log("onDisconnect, event", JSON.stringify(event));
                    },
                    onDestroy() {
                        console.log("onDestroy");
                    },
                    onAwarenessUpdate: ({ added, updated, removed }) => {
                        // …
                    },
                    onAwarenessChange: ({ states }) => {
                        // …
                    },
                    onStateless: ({ payload }) => {
                        console.log("onStateless, payload", payload);
                    },
                });

                extensions.push(
                    Collaboration.configure({
                        document: instance.data.provider.document,
                    }),
                    CollaborationCursor.configure({
                        provider: instance.data.provider,
                    })
                );
            } catch (error) {
                const message = "Error setting up custom collab";
                context.reportDebugger(message + error);
                console.log(message + error);
            }
            return;
        }

        function setupTiptapCloud(extensions, properties) {
            console.log("setting up TiptapCloud");
            const TiptapCollabProvider = window.tiptapCollabProvider;
            const Collaboration = window.tiptapCollaboration;
            const CollaborationCursor = window.tiptapCollaborationCursor;

            try {
                instance.data.provider = new TiptapCollabProvider({
                    appId: properties.collab_app_id,
                    name: properties.collab_doc_id,
                    token: properties.collab_jwt,
                });
            } catch (error) {
                const message = "Error setting up custom collab";
                context.reportDebugger(message + error);
                console.log(message + error);
            }

            extensions.push(
                Collaboration.configure({
                    document: instance.data.provider.document,
                }),
                CollaborationCursor.configure({
                    provider: instance.data.provider,
                })
            );

            return;
        }

        function setupLiveblocks(extensions, properties) {
            console.log("setting up collab with Liveblocks");
            if (!properties.liveblocksPublicApiKey) {
                context.reportDebugger(
                    "Liveblocks is selected but there's no plublic API key"
                );
                return;
            }
            const createClient = window.tiptapCreateClient;
            const LiveblocksProvider = window.tiptapLiveblocksProvider;
            const Collaboration = window.tiptapCollaboration;
            const CollaborationCursor = window.tiptapCollaborationCursor;
            const Y = window.tiptapY;

            try {
                const client = createClient({
                    publicApiKey: properties.liveblocksPublicApiKey,
                });

                const { room, leave } = client.enterRoom(properties.collab_doc_id, {
                    initialPresence: {},
                });

                const yDoc = new Y.Doc();
                const Text = yDoc.getText("tiptap");
                const Provider = new LiveblocksProvider(room, yDoc);

                extensions.push(
                    Collaboration.configure({
                        document: yDoc,
                    }),
                    CollaborationCursor.configure({
                        provider: Provider,
                    })
                );
            } catch (error) {
                context.reportDebugger(
                    "There was an error setting up Liveblocks. " + error
                );
            }

            return extensions;
        }
        instance.data.setupLiveblocks = setupLiveblocks;
    } catch (error) {
        console.log("error in initialize", error);
    }

    // MentionList
    instance.data.MentionList = class MentionList {
        constructor(stuff) {
            const { props, editor } = stuff;
            this.items = props.items;
            this.command = props.command;
            this.selectedIndex = 0;
            this.randomId = props.randomId;
            this.editor = editor;
            this.initElement();
            this.updateItems(this);
        }

        initElement() {
            this.element = document.createElement("div");
            this.element.className = "items_" + this.randomId;

            this.element.addEventListener("click", this.handleClick.bind(this));
            this.element.addEventListener("keydown", this.handleKeyDown.bind(this));
        }

        handleClick(event) {
            const target = event.target.closest(".item");
            const index = Array.from(this.element.children).indexOf(target);
            if (index !== -1) {
                this.selectItem(index);
                this.updateSelection(index);
            }
        }

        updateItems(props) {
            this.items = props.items;
            this.selectedIndex = 0;
            this.redraw();
        }

        updateProps(props) {
            this.range = props.range;
            this.editor = props.editor;
        }

        redraw() {
            this.element.innerHTML = "";
            const fragment = document.createDocumentFragment();

            this.items.forEach((item, index) => {
                const button = document.createElement("button");
                button.textContent = item.label;
                button.className =
                    "item" + (index === this.selectedIndex ? " is-selected" : "");
                fragment.appendChild(button);
            });

            this.element.appendChild(fragment);
        }

        selectItem(index) {
            const item = this.items[index];
            const editor = this.editor;
            const range = this.range;

            if (item && range) {
                editor.commands.insertContentAt(range, {
                    type: "mention",
                    attrs: {
                        label: item.label,
                        id: item.id,
                    },
                });
                editor.commands.insertContent(" ");
                editor.commands.setTextSelection(range.from + 1);
            } else {
                this.command(item);
            }
        }

        updateSelection(index) {
            const previouslySelected = this.element.querySelector(".is-selected");
            if (previouslySelected)
                previouslySelected.classList.remove("is-selected");

            const newSelected = this.element.children[index];
            if (newSelected) newSelected.classList.add("is-selected");

            this.selectedIndex = index;
        }

        handleKeyDown(event) {
            switch (event.key) {
                case "ArrowUp":
                    this.moveSelection(-1);
                    event.preventDefault();
                    break;
                case "ArrowDown":
                    this.moveSelection(1);
                    event.preventDefault();
                    break;
                case "Enter":
                    this.selectItem(this.selectedIndex);
                    event.preventDefault();
                    break;
                case "Tab":
                    this.selectItem(this.selectedIndex);
                    event.preventDefault();
                    break;
                             }
        }

        moveSelection(direction) {
            const itemLength = this.items.length;
            const newIndex =
                  (this.selectedIndex + direction + itemLength) % itemLength;
            this.updateSelection(newIndex);
            this.redraw();
        }
    };

    function configureSuggestion(instance, properties) {
        return {
            items: ({ query }) => {
                if (typeof query !== "string") {
                    // console.log("thing passed to Mention is not a string, returning. Typeof query: ", typeof query);
                    return [];
                }
                const length = properties.mention_list.length();
                const source_list = properties.mention_list.get(0, length);
                const mention_list = source_list.map((item) => {
                    return {
                        label: item.get(properties.mention_field_label),
                        id: item.get(properties.mention_field_id),
                    };
                });
                // console.log("mention_list", mention_list);
                const query_result = mention_list.filter((item) =>
                                                         item.label.toLowerCase().includes(query.toLowerCase())
                                                        );

                return query_result;
            },

            render: () => {
                let popup, component;

                return {
                    onStart: (props) => {
                        props.randomId = instance.data.randomId;
                        component = new instance.data.MentionList({
                            props,
                            editor: props.editor,
                        });
                        popup = window.tiptapTippy("body", {
                            getReferenceClientRect: props.clientRect,
                            appendTo: () => document.body,
                            content: component.element,
                            showOnCreate: true,
                            interactive: true,
                            trigger: "manual",
                            placement: "bottom-start",
                        });
                    },

                    onUpdate: (props) => {
                        if (!props.clientRect) {
                            return;
                        }

                        component.updateProps(props);

                        popup[0].setProps({
                            getReferenceClientRect: props.clientRect,
                        });

                        const newItems = component.updateItems(props);
                        popup[0].setContent(newItems);
                    },

                    onKeyDown: ({ event, editor }) => {
                        if (event.key === "Enter") {
                            event.preventDefault();
                            component.selectItem(component.selectedIndex);
                            return true;
                        }

                        return component.handleKeyDown(event);
                    },

                    onExit: () => {
                        popup[0].destroy();
                        component.element.remove();
                    },
                };
            },
        };
    }
    instance.data.configureSuggestion = configureSuggestion;

    instance.data.rgbToHex = function (colorString) {
        console.log("rgbToHex", colorString);

        // Regular expressions for RGB and RGBA
        const rgbRegex = /^rgb\((\d+),\s*(\d+),\s*(\d+)\)$/;
        const rgbaRegex = /^rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)$/;

        let match = colorString.match(rgbRegex) || colorString.match(rgbaRegex);

        if (!match) {
            console.error(
                'Invalid color string format. Expected "rgb(r, g, b)" or "rgba(r, g, b, a)"'
            );
            return null;
        }

        // Convert the extracted values to integers
        const r = parseInt(match[1], 10);
        const g = parseInt(match[2], 10);
        const b = parseInt(match[3], 10);

        // Handle alpha if present (for RGBA)
        let a = match[4] ? parseFloat(match[4]) : 1;

        // Ensure the values are within the valid range
        const clamp = (val) => Math.min(255, Math.max(0, val));

        // Convert to hex and pad with zeros if necessary
        const toHex = (val) => clamp(val).toString(16).padStart(2, "0");

        // Combine the hex values
        let hex = "#" + toHex(r) + toHex(g) + toHex(b);

        // Add alpha to hex if it's less than 1
        if (a < 1) {
            const alpha = Math.round(a * 255)
            .toString(16)
            .padStart(2, "0");
            hex += alpha;
        }

        return hex;
    };

    function findParentBlock(state, pos) {
        const $pos = state.doc.resolve(pos);
        for (let depth = $pos.depth; depth > 0; depth--) {
            const node = $pos.node(depth);
            if (node.type.isBlock) {
                return { node, pos: $pos.before(depth), depth };
            }
        }
        return null;

    }
    instance.data.findParentBlock = findParentBlock;    


    function getSelection(editor, properties) {
        const { state, view } = editor;
        const { from, to } = view.state.selection;
        const text = state.doc.textBetween(from, to, "");
        instance.publishState("selected_text", text);
        instance.publishState("from", from);
        instance.publishState("to", to);

        if (from === to) {
            // No selection, clear states
            instance.publishState("selectedContent", null);
            instance.publishState("selectedHTML", null);
            instance.publishState("selectedJSON", null);
            return;
        }

        try {
            const $from = state.doc.resolve(from);
            const $to = state.doc.resolve(to);
            let parentNode = $from.parent;
            let parentNodeType = parentNode.type.name;

            // Map ProseMirror node types to HTML tags
            const nodeTypeToHtmlTag = {
                'paragraph': 'p',
                'heading': 'h' + (parentNode.attrs.level || '1'), // h1, h2, etc.
                'bulletList': 'ul',
                'orderedList': 'ol',
                'listItem': 'li',
                'blockquote': 'blockquote',
                'codeBlock': 'pre',
                'horizontalRule': 'hr',
                'table': 'table',
                'tableRow': 'tr',
                'tableCell': 'td',
                'tableHeader': 'th'
            };

            const selectedNode = state.doc.slice(from, to);
            const selectedJSON = selectedNode.toJSON();
            const content = selectedJSON.content;

            // Get configured extensions
            const extensions = instance.data.getConfiguredExtensions(instance, properties);

            // Generate HTML from the JSON using the utility function
            let selectedHTML = window.tiptap.generateHTML({type: 'doc', content: content}, extensions);

            // If the selection is just text, wrap it with the appropriate HTML tag
            if (content.length === 1 && content[0].type === 'text') {
                const htmlTag = nodeTypeToHtmlTag[parentNodeType] || 'p';
                selectedHTML = `<${htmlTag}>${selectedHTML}</${htmlTag}>`;
            }

            instance.publishState("selectedContent", text);
            instance.publishState("selectedHTML", selectedHTML);
            instance.publishState("selectedJSON", JSON.stringify(selectedJSON));
        } catch (error) {
            console.error('Error generating JSON or HTML:', error);
        }
    }

    instance.data.getSelection = getSelection;

    function getConfiguredExtensions(instance, properties) {
        // pull the libraries that were loaded on Header
        const Heading = window.tiptapHeading;
        const Bold = window.tiptapBold;
        const Code = window.tiptapCode;
        const Italic = window.tiptapItalic;
        const Strike = window.tiptapStrike;
        const Dropcursor = window.tiptapDropcursor;
        const Gapcursor = window.tiptapGapcursor;
        const History = window.tiptapHistory;
        const Blockquote = window.tiptapBlockquote;
        const BulletList = window.tiptapBulletList;
        const CodeBlock = window.tiptapCodeBlock;
        const HorizontalRule = window.tiptapHorizontalRule;
        const ListItem = window.tiptapListItem;
        const OrderedList = window.tiptapOrderedList;

        const {
            Editor,
            Node,
            Extension,
            mergeAttributes,
            Document,
            HardBreak,
            Paragraph,
            Text,
            FontFamily,
            Color,
            TextStyle,
            FileHandler,
            generateHTML,
            DragHandle,
            UniqueID,
            Image,
            Resizable
        } = window.tiptap;


        const TaskList = window.tiptapTaskList;
        const TaskItem = window.tiptapTaskItem;
        const Placeholder = window.tiptapPlaceholder;
        const CharacterCount = window.tiptapCharacterCount;
        const BubbleMenu = window.tiptapBubbleMenu;
        const FloatingMenu = window.tiptapFloatingMenu;
        const Link = window.tiptapLink;
        const TextAlign = window.tiptapTextAlign;
        const Highlight = window.tiptapHighlight;
        const Table = window.tiptapTable;
        const TableCell = window.tiptapTableCell;
        const TableHeader = window.tiptapTableHeader;
        const TableRow = window.tiptapTableRow;
        const Underline = window.tiptapUnderline;
        const Youtube = window.tiptapYoutube;

        const Mention = window.tiptapMention;
        
        instance.data.active_nodes = properties.nodes
            .split(",")
            .map((item) => item.trim());

        const extensions = [
            Document,
            Paragraph,
            Text,
            ListItem,
            TextStyle,
            CharacterCount.configure({
                limit: properties.characterLimit || null,
            }),
        ];

        if (instance.data.active_nodes.includes("Dropcursor")) extensions.push(Dropcursor);
        if (instance.data.active_nodes.includes("Gapcursor")) extensions.push(Gapcursor);
        if (instance.data.active_nodes.includes("HardBreak")) extensions.push(HardBreak);
        if (instance.data.active_nodes.includes("History")) extensions.push(History);
        if (instance.data.active_nodes.includes("Bold")) extensions.push(Bold);
        if (instance.data.active_nodes.includes("Italic")) extensions.push(Italic);
        if (instance.data.active_nodes.includes("Strike")) extensions.push(Strike);
        if (instance.data.active_nodes.includes("FontFamily")) extensions.push(FontFamily);
        if (instance.data.active_nodes.includes("Color")) extensions.push(Color);
        if (instance.data.active_nodes.includes("Heading")) extensions.push(Heading);
        if (instance.data.active_nodes.includes("BulletList")) extensions.push(BulletList);
        if (instance.data.active_nodes.includes("OrderedList")) extensions.push(OrderedList);
        if (instance.data.active_nodes.includes("TaskList")) {
            extensions.push(TaskList, TaskItem);
        }
        if (instance.data.active_nodes.includes("Highlight")) extensions.push(Highlight);
        if (instance.data.active_nodes.includes("Underline")) extensions.push(Underline);
        if (instance.data.active_nodes.includes("CodeBlock")) extensions.push(CodeBlock);
        if (instance.data.active_nodes.includes("Code")) extensions.push(Code);
        if (instance.data.active_nodes.includes("Blockquote")) extensions.push(Blockquote);
        if (instance.data.active_nodes.includes("HorizontalRule")) extensions.push(HorizontalRule);
        if (instance.data.active_nodes.includes("Youtube")) extensions.push(Youtube);
        if (instance.data.active_nodes.includes("Table")) {
            extensions.push(Table, TableRow, TableHeader, TableCell);
        }
        if (instance.data.active_nodes.includes("Image")) extensions.push(Image);
        if (instance.data.active_nodes.includes("Link")) extensions.push(Link);
        if (instance.data.active_nodes.includes("Placeholder")) extensions.push(Placeholder);
        if (instance.data.active_nodes.includes("TextAlign")) extensions.push(TextAlign);

        return extensions;
    }
    instance.data.getConfiguredExtensions = getConfiguredExtensions;

}


