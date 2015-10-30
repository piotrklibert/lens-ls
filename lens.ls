z = require "lodash"            # `_` is a syntactic construct in LS
{reverse, fold1, map} = require "prelude-ls"

pass-thru = (f, v) --> (f v); v
abstract-method = -> throw new Error("Abstract method")


#
# LensProto - a prototype of all lens objects.
#
LensProto =
    # essential methods which need to be implemented on all lens instances
    get: abstract-method (obj) ->
    set: abstract-method (obj, val) ->
    update: (obj, update_func) ->
        (@get obj)
        |> update_func
        |> @set obj, _

    # convenience functions
    add: (obj, val) ->
        @update obj, (+ val)


#
# Lens constructors
#
make-lens = (name) ->
    LensProto with
        get: (.[name])
        set: (obj, val) ->
            (switch typeof! obj
                | \Object => ^^obj <<< obj
                | \Array  => obj.slice 0  )
            |> pass-thru (.[name] = val)

make-lenses = (...lenses) ->
    map make-lens, lenses


#
# Lenses composition
#
comp-lens = (L1, L2) ->
    LensProto with
        get: L2.get >> L1.get
        set: (obj, val) ->
            L2.update obj, (obj2) ->
                L1.set obj2, val


#
# Convenience functions
#

# Lensable is a mix-in, which can be used with any object and which provides two
# methods for obtaining lenses for given names. The lens returned is bound to
# the object, which allows us to write:
#
#   obj.l("...").get()
#   obj.l("...").set new_val
#
# instead of
#
#   make-lens("...").get obj
#   make-lens("...").set obj, new_value
#
Lensable =
    # `at` - convenience function for creating and binding a lens from a string
    # path, with components separated by slash; for example: "a/f/z"
    at: (str) -> @l(...str.split("/"))

    l: (...names) ->
        # create lenses for the names and compose them all into a single lens
        lens = reverse names
            |> map make-lens
            |> fold1 comp-lens

        # bind the lens to `this` object
        lens with
            get:  ~> lens.get this
            set: (val) ~> lens.set this, val

to-lensable = (obj) -> Lensable with obj


#
# Tests
#

o = Lensable with
    prop:
        bobr: "omigott!"
        dammit: 0


[prop, dammit] = make-lenses "prop", "dammit"
prop-dammit = dammit `comp-lens` prop


console.log z.is-equal (prop.get o),
    { bobr: 'omigott!', dammit: 0 }

console.log (prop-dammit.get o) == 0

console.log z.is-equal (prop-dammit.set o, 10),
    { prop: { bobr: 'omigott!', dammit: 10 } }

prop-dammit
    |> (.set o, "trite")
    |> (.l("prop", "bobr").set -10)
    |> z.is-equal { prop: { bobr: -10, dammit: 'trite' } }, _
    |> console.log


out = o
    .at("prop/bobr").set "12312"
    .at("prop/argh").set "scoobydoobydoooya"
    .at("prop/lst").set [\c \g]
    .at("prop/dammit").add -10
    .l("prop", "lst", 0).set \a
    .l("prop", "lst", 2).set \a

console.log z.is-equal out, {
    prop: {
        bobr: '12312', dammit: -10,
        argh: 'scoobydoobydoooya',
        lst: ["a", "g", "a"]}}


out = o
    .at("prop/bobr").set "12312"
    .at("prop/argh").set "scoobydoobydoooya"
    .at("prop/dammit").add -10

console.log z.is-equal out,
    { prop: { bobr: '12312', dammit: -10, argh: 'scoobydoobydoooya' } }


transform =
    (.at("prop/bobr").set "12312") >>
    (.at("prop/argh").set "scoobydoooya") >>
    (.at("prop/dammit").add -10)

console.log z.is-equal  (transform o),
    { prop: { bobr: '12312', dammit: -10, argh: 'scoobydoooya' } }


# Not used right now
# L = Proxy.create({
#     get: (target, property, receiver) ->
#         make-lens property
#     getPropertyDescriptor: (key) ->
#       o = @target;
#       while o
#         desc = Object.getOwnPropertyDescriptor(o, key)
#         if desc
#           desc.configurable = true
#           return desc
#         o = Object.getPrototypeOf(o)
#     ,
# })
# prop = L \prop
# bobr = L \bobr
